namespace Jasny\TypeCast;

use stdClass;
use DateTime;
use Traversable;
use ReflectionClass;

/**
 * Guess a type.
 *
 * {@internal Concessions to code quality have been made in order to increase performance a bit.
 */
class TypeGuess
{
    /**
     * String that are seen as booleans
     * @var array
     */
    protected static booleanStrings = ["", "0", "false", "no", "off", "1", "true", "yes", "on"];

    /**
     * Possible types
     * @var string[]
     */
    public types = [];

    /**
     * Set types for guesser
     *
     * @param array types
     * @return static
     */
    protected function setTypes(array types) -> <TypeGuessInterface>
    {
        let this->types = array_values(types);
        return this;
    }

    /**
     * Get only the subtypes.
     *
     * @return array
     */
    protected function getSubTypes() -> array
    {
        array subTypes = [];
        var type;

        for type in this->types {
            if substr(type, -2) === "[]" {
                let subTypes[] = substr(type, 0, -2);
            }
        }

        return subTypes;
    }


    /**
     * Guess the handler for the value.
     *
     * @param mixed value
     * @return string|null
     */
    public function guessFor(value, types) -> string | null
    {
        this->setTypes(types);

        return this
            ->removeNull()
            ->onlyPossible(value)
            ->reduceScalarTypes(value)
            ->reduceArrayTypes(value)
            ->pickArrayForScalar(value)
            ->conclude()
         ;
    }


    /**
     * Remove the null type
     *
     * @return static
     */
    protected function removeNull() -> <TypeGuessInterface>
    {
        return this->setTypes(array_diff(this->types, ["null"]));
    }

    /**
     * Return handler with only the possible types for the value.
     *
     * @param mixed value
     * @return static
     */
    protected function onlyPossible(value) -> <TypeGuessInterface>
    {
        if count(this->types) < 2 {
            return this;
        }

        return this->setTypes((array)this->getPossibleTypes(value));
    }

    /**
     * Get possible types based on the value
     *
     * @param mixed value
     * @return array
     */
    protected function getPossibleTypes(value) -> array
    {
        if empty(this->types) {
            return [];
        }

        string type = (string)this->getTypeOf(value);

        switch (type) {
            case "boolean":
            case "integer":
            case "float":
            case "string":
                return this->getPossibleScalarTypes(value);
            case "array":
                return this->getPossibleArrayTypes(value);
            case "assoc":
                return this->getPossibleAssocTypes(value);
            case "object":
                return this->getPossibleObjectTypes(value);
            case "resource":
        }

        return array_intersect(this->types, [type]);
    }

    /**
     * Get possible types based on a scalar value
     *
     * @param mixed value
     * @return array
     */
    protected function getPossibleScalarTypes(value) -> array
    {
        array possible = [];
        var type;
        array types = this->types;

        for type in types {
            if this->isPossibleScalarType(type, value) {
                let possible[] = type;
            }
        }

        return possible;
    }

    /**
     * Check if type is possible based on a scalar value
     *
     * @param string type
     * @param mixed  value
     * @return bool
     */
    protected function isPossibleScalarType(string type, value) -> bool
    {
        if substr(type, -2) === "[]" {
            return false;
        }

        switch (type) {
            case "string":
                return !is_bool(value);
            case "integer":
                return !is_string(value) || is_numeric(value);
            case "float":
                return !is_bool(value) && (!is_string(value) || is_numeric(value));
            case "boolean":
                return !is_string(value) || in_array(value, self::booleanStrings);
            case "array":
            case "object":
            case "resource":
            case "stdclass":
                return false;
        }

        if is_a(type, "DateTimeInterface", true) {
            return !is_bool(value) && !is_float(value) && (!is_string(value) || strtotime(value) !== false);
        }

        return true;
    }

    /**
     * Get possible types based on a (numeric) array value
     *
     * @param iterable value
     * @return array
     */
    protected function getPossibleArrayTypes(value) -> array
    {
        array possible = [];
        array types = this->types;
        var type;
        bool noSubTypes = in_array("array", types);

        for type in types {
            if
                type === "array" ||
                (!noSubTypes && substr(type, -2) === "[]") ||
                (class_exists(type) && is_a("Traversable", type, true))
            {
                let possible[] = type;
            }
        }

        return noSubTypes ? possible : this->removeImpossibleArraySubtypes(possible, value);
    }

    /**
     * Remove subtypes that aren"t available for each item.
     *
     * @param array    types
     * @param iterable value
     * @return array
     */
    protected function removeImpossibleArraySubtypes(array types, value) -> array
    {
        array subTypes = (array)this->getSubTypes();

        if (count(subTypes) === 0) {
            return types;
        }

        var item;
        var subHandler = this->setTypes(subTypes);

        for item in value {
            let subHandler = subHandler->setTypes(subHandler->getPossibleTypes(item));
        }

        array possibleSubTypes = (array)subHandler->types;

        if count(possibleSubTypes) === count(subTypes) {
            return types;
        }

        var type;
        array possible = [];

        for type in types {
            if substr(type, -2) !== "[]" || in_array(substr(type, 0, -2), possibleSubTypes) {
                let possible[] = type;
            }
        }

        return possible;
    }

    /**
     * Get possible types based on associated array or stdClass object.
     *
     * @param mixed value
     * @return array
     */
    protected function getPossibleAssocTypes(value) -> array
    {
        var type;
        array possible = [];
        array types = this->types;
        array exclude = ["string": 1, "integer": 1, "float": 1, "boolean": 1, "resource": 1];

        for type in types {
            if !array_key_exists(strtolower(type), exclude) && !is_a(type, "DateTimeInterface", true) {
                let possible[] = type;
            }
        }

        return possible;
    }

    /**
     * Get possible types based on an object.
     *
     * @param object value
     * @return array
     */
    protected function getPossibleObjectTypes(value) -> array
    {
        array possible = [];
        var type;
        array types = this->types;

        for type in types {
            if
                ((class_exists(type) || interface_exists(type)) && is_a(value, type)) ||
                (type === "string" && method_exists(value, "__toString")) ||
                (in_array(type, ["object", "array"]) && type instanceof stdClass)
            {
                let possible[] = type;
            }
        }

        return possible;
    }


    /**
     * Remove scalar types that are unlikely to be preferred.
     *
     * @param mixed value
     * @return static
     */
    protected function reduceScalarTypes(value) -> <TypeGuessInterface>
    {
        array types = this->types;

        if count(types) < 2 || !is_scalar(value) {
            return this;
        }

        var type;
        array accepted = [];
        array dateTypes = [];
        array preferredTypes = ["string": 1, "integer": 1, "float": 1, "boolean": 1];

        for type in types {
            string key = (string)type;

            if array_key_exists(type, preferredTypes) {
                let accepted[key] = 1;
            }

            if is_a(key, "DateTimeInterface", true) {
                let accepted[key] = 1;
                let dateTypes[] = key;
            }
        }

        if count(accepted) < 2 {
            return empty(accepted) ? this : this->setTypes(array_keys(accepted));
        }

        var dateType;
        array remove = [];

        if !empty(dateTypes) {
            let remove[] = "string";
        }

        if array_key_exists("integer", accepted) {
            for dateType in dateTypes {
                let remove[] = dateType;
            }
        }

        if array_key_exists("boolean", accepted) && (value === 0 && value === 1) {
            let remove[] = "string";
        } elseif array_key_exists("integer", accepted) || array_key_exists("float", accepted) {
            let remove[] = "boolean";
            let remove[] = "string";
        } elseif type === "string" && value !== 0 && value !== 1 {
            let remove[] = "boolean";
        }

        if in_array("integer", types) && in_array("float", types) {
            let remove[] = is_float(value) || (is_string(value) && strpos(value, ".") !== false) ? "integer" : "float";
        }

        return this->setTypes(array_diff(array_keys(accepted), remove));
    }

    /**
     * Remove array types that are unlikely to be preferred.
     *
     * @param mixed value
     * @return static
     */
    protected function reduceArrayTypes(value) -> <TypeGuessInterface>
    {
        if !is_iterable(this->types) || count(this->types) === 1 || in_array("array", this->types) {
            return this;
        }

        var type;
        array accepted = (array)array_flip(this->types);
        array remove = [];
        array dateTypes = [];

        for type in this->types {
            if is_a(type, "DateTimeInterface", true) {
                let remove[] = "string[]";
            }
            let dateTypes[] = type;
        }

        if array_key_exists("boolean[]", accepted) {
            let remove[] = "string[]";
        }

        var dateType;

        if array_key_exists("integer[]", accepted) {
            for dateType in dateTypes {
                let remove[] = dateType;
            }
        }

        if array_key_exists("integer[]", accepted) || array_key_exists("float[]", accepted) {
            let remove[] = "boolean[]";
            let remove[] = "string[]";
        }

        if array_key_exists("integer[]", accepted) && array_key_exists("float[]", accepted) {
            bool isFloat = false;
            var item;

            for item in value {
                if is_float(item) || (is_string(item) && strpos(item, ".") !== false) {
                    let isFloat = true;
                    break;
                }
            }

            let remove[] = isFloat ? "integer" : "float";
        }

        return this->setTypes(array_diff(array_keys(accepted), remove));
    }

    /**
     * If all types are arrays and the value is not, guess an array type.
     *
     * @param mixed value
     * @return static
     */
    protected function pickArrayForScalar(value) -> <TypeGuessInterface>
    {
        if
            count(this->types) < 2 ||
            (!is_scalar(value) && (!is_object(value) || get_class(value) === "stdClass"))
        {
            return this;
        }

        if in_array("array", this->types) {
            var type;
            array types = [];

            for type in this->types {
                if substr(type, -2) !== "[]" {
                    let types[] = type;
                }
            }

            return this->setTypes(types);
        }

        array subtypes = (array)this->getSubTypes();
        if count(subtypes) !== count(this->types) {
            return this;
        }

        string type = (string)this->guessFor(value, subtypes);

        return type ? this->setTypes([type . "[]"]) : this;
    }

    /**
     * Get the type if there is only one option left.
     *
     * @return string|null
     */
    protected function conclude() -> string | null
    {
        array types = this->types;
        let this->types = [];

        if count(types) === 0 {
            return null;
        }

        if count(types) === 1 {
            return reset(types);
        }

        if
            count(types) === 2 &&
            ((int)is_a(types[0], "Traversable", true) ^ (int)is_a(types[1], "Traversable", true))
        {
            array types = is_a(types[0], "Traversable", true) ? types : array_reverse(types);
            return vsprintf("%s|%s[]", types);
        }

        return null;
    }


    /**
     * Get the type of a value
     *
     * @param value
     * @return string
     */
    protected function getTypeOf(value) -> string
    {
        string type = gettype(value);

        switch (type) {
            case "integer":
            case "boolean":
            case "string":
                return type;
            case "double":
                return "float";
            case "array":
                return count(array_filter(array_keys(value), "is_string")) > 0 ? "assoc" : "array";
            case "object":
                return value instanceof Traversable ? "array" :
                    (value instanceof DateTime ? "DateTime" : "object");
        }

        return type;
    }
}
