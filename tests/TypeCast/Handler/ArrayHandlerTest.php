<?php

namespace Jasny\TypeCast\Test\Handler;

use PHPUnit\Framework\TestCase;
use Jasny\TypeCast;
use Jasny\TestHelper;
use Jasny\TypeCastInterface;
use Jasny\TypeCast\Handler\ArrayHandler;

/**
 * @covers \Jasny\TypeCast\Handler
 * @covers \Jasny\TypeCast\Handler\ArrayHandler
 */
class ArrayHandlerTest extends TestCase
{
    use TestHelper;

    /**
     * @var ArrayHandler
     */
    protected $handler;

    public function setUp()
    {
        $this->handler = new ArrayHandler();
    }

    public function testUsingTypecast()
    {
        $typecast = $this->createMock(TypeCastInterface::class);

        $newHandler = $this->handler->usingTypecast($typecast);

        $this->assertNotSame($this->handler, $newHandler);
        $this->assertAttributeSame($typecast, 'typecast', $newHandler);

        $this->assertAttributeSame(null, 'typecast', $this->handler);
    }

    public function testForTypeNoCast()
    {
        $ret = $this->handler->forType('array');

        $this->assertSame($this->handler, $ret);
        $this->assertAttributeSame(null, 'subtype', $this->handler);
    }

    public function testForTypeSubtype()
    {
        $newHandler = $this->handler->forType('string[]');

        $this->assertInstanceOf(ArrayHandler::class, $newHandler);
        $this->assertNotSame($this->handler, $newHandler);
        $this->assertAttributeEquals('string', 'subtype', $newHandler);

        $this->assertAttributeSame(null, 'subtype', $this->handler);

        return $newHandler;
    }

    /**
     * @depends testForTypeSubtype
     */
    public function testForTypeWithoutSubtype($handler)
    {
        $newHandler = $handler->forType('array');

        $this->assertInstanceOf(ArrayHandler::class, $newHandler);
        $this->assertNotSame($handler, $newHandler);
        $this->assertAttributeSame(null, 'subtype', $newHandler);

        $this->assertAttributeEquals('string', 'subtype', $handler);
    }

    /**
     * @depends testForTypeSubtype
     */
    public function testForTypeSameSubtype($handler)
    {
        $ret = $handler->forType('string[]');

        $this->assertSame($handler, $ret);
        $this->assertAttributeEquals('string', 'subtype', $handler);
    }

    /**
     * @expectedException LogicException
     */
    public function testForTypeInvalidArgument()
    {
        $this->handler->forType('string');
    }

    public function castProvider()
    {
        $assoc = ['red' => 1, 'green' => 20, 'blue' => 300];
        $object = new \DateTime();

        return [
            [null, null],
            [[], []],
            [[1, 20, 300], [1, 20, 300]],
            [['foo', 'bar'], ['foo', 'bar']],
            [$assoc, $assoc],
            [$assoc, (object)$assoc],
            [$assoc, new \ArrayObject($assoc)],
            [[20], 20],
            [[false], false],
            [[], ''],
            [['foo'], 'foo'],
            [['100, 30, 40'], '100, 30, 40'],
            [[$object], $object],
        ];
    }

    /**
     * @dataProvider castProvider
     */
    public function testCast($expected, $value)
    {
        $this->assertSame($expected, $this->handler->cast($value));
    }

    public function testCastWithResource()
    {
        if (!function_exists('imagecreate')) {
            $this->markTestSkipped("GD not available. Using gd resource for test.");
        }

        $resource = imagecreate(10, 10);
        $ret = @$this->handler->cast($resource);

        $this->assertSame($resource, $ret);

        $this->assertLastError(E_USER_NOTICE, "Unable to cast gd resource to array");
    }

    /**
     * Test 'forType' method, if multiple types are passed
     */
    public function testForTypeMultiple()
    {
        $handler = $this->handler->forType('FooTraversable|FooSubtype[]');

        $this->assertAttributeEquals('FooTraversable', 'traversable', $handler);
        $this->assertAttributeEquals('FooSubtype', 'subtype', $handler);
    }

    /**
     * Test 'forType' method, if traversable type is passed
     */
    public function testForTypeTraversable()
    {
        $handler = $this->handler->forType('Iterator');

        $this->assertAttributeEquals('Iterator', 'traversable', $handler);
        $this->assertAttributeEquals(null, 'subtype', $handler);
    }

    /**
     * Test 'usingTypecast' method, if the same typecast instance is assigned
     */
    public function testUsingTypecastSame()
    {
        $typecast = $this->createMock(TypeCastInterface::class);
        $handler = $this->handler->usingTypecast($typecast);

        $this->assertAttributeEquals($typecast, 'typecast', $handler);
        $this->assertNotSame($this->handler, $handler);

        $handler2 = $handler->usingTypecast($typecast);

        $this->assertAttributeEquals($typecast, 'typecast', $handler2);
        $this->assertSame($handler, $handler2);
    }

    /**
     * Test 'cast' method, if traversable property is not a Traversable
     */
    public function testCastWrongTraversable()
    {
        $this->setPrivateProperty($this->handler, 'traversable', 'WrongIterator');

        $result = @$this->handler->cast('foo');

        $this->assertLastError(E_USER_NOTICE, 'Unable to cast string "foo" to WrongIterator: WrongIterator is not Traversable');
    }

    /**
     * Test 'castEach' method
     */
    public function testCastEach()
    {
        $typecast = new TypeCast();
        $handler = $this->handler->forType('string[]')->usingTypecast($typecast);
        $result = $handler->cast([10, 20]);

        $this->assertAttributeEquals('string', 'subtype', $handler);
        $this->assertSame(['10', '20'], $result);
    }

    /**
     * Test 'castEach' method, if typecast is not set
     *
     * @expectedException LogicException
     * @expectedExceptionMessage Typecast for array handler not set
     */
    public function testCastEachNoTypecast()
    {
        $handler = $this->handler->forType('string[]');

        $handler->cast([10, 20]);
    }

    /**
     * Test 'cast' method, if we should cast to Traversable
     */
    public function testCastTraversable()
    {
        $handler = $this->handler->forType(\ArrayObject::class);

        $result = $handler->cast(['foo', 'bar']);

        $this->assertInstanceOf(\ArrayObject::class, $result);
    }
}
