package flow;

import logs.*;
import modules.*;

using StringTools;

class Program {
    public var statements:Array<Statement>;

    public function new(statements:Array<Statement>) {
        this.statements = statements;
    }

    public function execute():Void {
        for (statement in statements) {
            statement.execute();
        }
    }
}

class Statement {
    public function execute():Void {}
}

class PrintStatement extends Statement {
    public var expression:Expression;

    public function new(expression:Expression) {
        this.expression = expression;
    }

    public override function execute():Void {
        var value:String = expression.evaluate();
        var lines:Array<String> = value.split("\n");
        for (line in lines) {
            Logger.log(line);
        }
    }
}

class LetStatement extends Statement {
    public var name:String;
    public var initializer:Expression;

    public function new(name:String, initializer:Expression) {
        this.name = name;
        this.initializer = initializer;
    }

    public override function execute():Void {
        Environment.define(name, initializer.evaluate());
    }
}

class VariableExpression extends Expression {
    public var name:String;

    public function new(name:String) {
        this.name = name;
    }

    public override function evaluate():Dynamic {
        return Environment.get(name);
    }
}

class Environment {
    static public var values:Map<String, Dynamic> = new Map();
    static public var functions:Map<String, Function> = new Map();
    static public var currentScope:Scope = new Scope();

    static public function define(name:String, value:Dynamic):Void {
        values.set(name, value);
    }

    static public function get(name: String): Dynamic {
        var parts: Array<String> = name.split(".");
        var obj: Dynamic = values.get(parts[0]);

        if (obj == null && currentScope != null) {
            for (letStatement in currentScope.letStatements) {
                if (letStatement.name == parts[0]) {
                    return null;
                }
            }
        }

        if (obj == null) {
            Flow.error.report("Undefined variable: " + parts[0]);
            return null;
        }

        for (i in 1...parts.length) {
            if (obj == null) {
                Flow.error.report("Undefined property: " + parts[i - 1]);
                return null;
            }

            if (parts[i] == "length") {
                if (Std.is(obj, String) || Std.is(obj, Array)) {
                    obj = obj.length;
                } else {
                    Flow.error.report("Cannot access 'length' property on non-array/non-string.");
                    return null;
                }
            } else {
                if (Reflect.hasField(obj, parts[i])) {
                    obj = Reflect.field(obj, parts[i]);
                } else {
                    Flow.error.report("Undefined property: " + parts[i]);
                    return null;
                }
            }
        }

        return obj;
    }

    static public function defineFunction(name:String, func:Dynamic):Void {
        functions.set(name, func);
    }

    static public function getFunction(name:String, context:Dynamic = null):Dynamic {
        if (context != null) {
            var parts: Array<String> = name.split(".");
            var methodName: String = parts.pop();
            var obj: Dynamic = context;

            for (part in parts) {
                if (obj == null) {
                    Flow.error.report("Undefined property: " + part);
                    return null;
                }
    
                if (Reflect.hasField(obj, part)) {
                    obj = Reflect.field(obj, part);
                } else {
                    Flow.error.report("Undefined property: " + part);
                    return null;
                }
            }
    
            var func: Dynamic = Reflect.field(obj, methodName);
            if (func == null || !(func is Function)) {
                Flow.error.report("Undefined method: " + methodName);
                return null;
            }
            return func;
        } else {
            var func: Dynamic = functions.get(name);
            if (func == null) {
                Flow.error.report("Undefined function: " + name);
                return null;
            }
            return func;
        }
    }

    static public function callFunction(name: String, arguments: Array<Dynamic>, context: Dynamic = null): Dynamic {
        var func: Dynamic = getFunction(name, context);

        if (func == null) {
            Flow.error.report("Function or method could not be found: " + name);
            return null;
        }

        if (Std.is(func, Function)) {
            try {
                return Reflect.callMethod(context, func, arguments);
            } catch (e: Dynamic) {
                Flow.error.report("Error calling function: " + name + " - " + e.toString());
                return null;
            }
        } else {
            Flow.error.report("Retrieved item is not a function: " + name);
            return null;
        }
    }

    static public function push(array:Array<Dynamic>, value:Dynamic):Void {
        if (array == null) {
            Flow.error.report("Cannot push to null array");
            return;
        }
        array.push(value);
    }

    static public function pop(array:Array<Dynamic>):Dynamic {
        if (array == null) {
            Flow.error.report("Cannot pop from null array");
            return null;
        }
        if (array.length == 0) {
            Flow.error.report("Cannot pop from empty array");
            return null;
        }
        return array.pop();
    }
}

class Scope {
    public var letStatements:Array<LetStatement> = new Array();
    public var parentScope:Scope;

    public function new(parentScope:Scope = null) {
        this.parentScope = parentScope;
    }
}

class Expression {
    public function evaluate():Dynamic {
        return null;
    }
}

class LiteralExpression extends Expression {
    public var value:Dynamic;

    public function new(value:Dynamic) {
        this.value = value;
    }

    public override function evaluate():Dynamic {
        return value;
    }
}

class BinaryExpression extends Expression {
    public var left:Expression;
    public var opera:String;
    public var right:Expression;

    public function new(left:Expression, opera:String, right:Expression) {
        this.left = left;
        this.opera = opera;
        this.right = right;
    }

    public override function evaluate():Dynamic {
        var leftValue = left.evaluate();
        var rightValue = right.evaluate();

        var leftIsFloat = Std.is(leftValue, Float);
        var rightIsFloat = Std.is(rightValue, Float);
        var leftIsString = Std.is(leftValue, String);
        var rightIsString = Std.is(rightValue, String);

        if (!leftIsFloat &&!leftIsString) {
            Flow.error.report("Unsupported left operand type for operator: " + opera);
            return null;
        }
        if (!rightIsFloat &&!rightIsString) {
            Flow.error.report("Unsupported right operand type for operator: " + opera);
            return null;
        }

        if (leftIsFloat) leftValue = cast(leftValue, Float);
        if (rightIsFloat) rightValue = cast(rightValue, Float);

        switch (opera) {
            case "+":
                if (leftIsString || rightIsString) {
                    return Std.string(leftValue) + Std.string(rightValue);
                } else {
                    return leftValue + rightValue;
                }
            case "-":
                if (leftIsString || rightIsString) {
                    Flow.error.report("Unsupported operator for strings: " + opera);
                    return null;
                } else {
                    return leftValue - rightValue;
                }
            case "*":
                if (leftIsString || rightIsString) {
                    Flow.error.report("Unsupported operator for strings: " + opera);
                    return null;
                } else {
                    return leftValue * rightValue;
                }
            case "/":
                if (leftIsString || rightIsString) {
                    Flow.error.report("Unsupported operator for strings: " + opera);
                    return null;
                } else if (rightValue == 0) {
                    Flow.error.report("Division by zero error");
                    return null;
                } else {
                    return leftValue / rightValue;
                }
            case "%":
                if (leftIsString || rightIsString) {
                    Flow.error.report("Unsupported operator for strings: " + opera);
                    return null;
                } else if (rightValue == 0) {
                    Flow.error.report("Modulo by zero error");
                    return null;
                } else {
                    return leftValue % rightValue;
                }
            case "==":
                return leftValue == rightValue;
            case "!=":
                return leftValue!= rightValue;
            case "<":
                if (leftIsString || rightIsString) {
                    Flow.error.report("Unsupported operator for strings: " + opera);
                    return null;
                } else {
                    return leftValue < rightValue;
                }
            case "<=":
                if (leftIsString || rightIsString) {
                    Flow.error.report("Unsupported operator for strings: " + opera);
                    return null;
                } else {
                    return leftValue <= rightValue;
                }
            case ">":
                if (leftIsString || rightIsString) {
                    Flow.error.report("Unsupported operator for strings: " + opera);
                    return null;
                } else {
                    return leftValue > rightValue;
                }
            case ">=":
                if (leftIsString || rightIsString) {
                    Flow.error.report("Unsupported operator for strings: " + opera);
                    return null;
                } else {
                    return leftValue >= rightValue;
                }
            case "and":
                if (leftIsString || rightIsString) {
                    Flow.error.report("Unsupported operator 'and' for strings");
                    return null;
                } else {
                    return (leftValue!= 0) && (rightValue!= 0);
                }
            case "or":
                if (leftIsString || rightIsString) {
                    Flow.error.report("Unsupported operator 'or' for strings");
                    return null;
                } else {
                    return (leftValue!= 0) || (rightValue!= 0);
                }
            default:
                Flow.error.report("Unknown operator: " + opera);
                return null;
        }
    }
}

class ConcatenationExpression extends Expression {
    public var parts:Array<Expression>;

    public function new(parts:Array<Expression>) {
        this.parts = parts;
    }

    public override function evaluate():Dynamic {
        var result:String = "";
        for (part in parts) {
            var partValue:Dynamic = part.evaluate();
            if (partValue == null) {
                partValue = "null";
            } else {
                partValue = Std.string(partValue);
            }
            result += partValue;
        }
        return result;
    }
}

class IfStatement extends Statement {
    public var condition:Expression;
    public var thenBranch:Statement;
    public var elseBranch:Statement;

    public function new(condition:Expression, thenBranch:Statement, elseBranch:Statement = null) {
        this.condition = condition;
        this.thenBranch = thenBranch;
        this.elseBranch = elseBranch;
    }

    public override function execute():Void {
        if (condition.evaluate()) {
            thenBranch.execute();
        } else if (elseBranch != null) {
            elseBranch.execute();
        }
    }
}

class ElseStatement extends Statement {
    public var body:Statement;

    public function new(body:Statement) {
        this.body = body;
    }

    public override function execute():Void {
        body.execute();
    }
}

class BlockStatement extends Statement {
    public var statements:Array<Statement>;

    public function new(statements:Array<Statement>) {
        this.statements = statements;
    }

    public override function execute():Void {
        for (statement in statements) {
            statement.execute();
        }
    }
}

class WhileStatement extends Statement {
    public var condition:Expression;
    public var body:Statement;

    public function new(condition:Expression, body:Statement) {
        this.condition = condition;
        this.body = body;
    }

    public override function execute():Void {
        while (condition.evaluate()) {
            try {
                body.execute();
            } catch (e:BreakException) {
                break;
            } catch (e:ContinueException) {
                continue;
            }
        }
    }
}

class ForStatement extends Statement {
    public var variableName:String;
    public var iterableExpression:Expression;
    public var body:Statement;

    public function new(variableName:String, iterableExpression:Expression, body:Statement) {
        this.variableName = variableName;
        this.iterableExpression = iterableExpression;
        this.body = body;
    }

    public override function execute():Void {
        var iterable:Iterable<Dynamic> = iterableExpression.evaluate();

        if (iterable != null) {
            for (item in iterable) {
                Environment.define(variableName, item);
                try {
                    body.execute();
                } catch (e:BreakException) {
                    break;
                } catch (e:ContinueException) {
                    continue;
                }
            }
        } else {
            Flow.error.report("Iterable expression evaluates to null");
        }
    }
}

class RangeExpression extends Expression {
    public var start:Expression;
    public var end:Expression;

    public function new(start:Expression, end:Expression) {
        this.start = start;
        this.end = end;
    }

    public override function evaluate():Iterable<Int> {
        var startValue:Dynamic = start.evaluate();
        var endValue:Dynamic = end.evaluate();

        if (!Std.is(startValue, Int) || !Std.is(endValue, Int)) {
            Flow.error.report("Range start or end value is not a valid integer");
            return null;
        }

        return new RangeIterable(cast(startValue, Int), cast(endValue, Int));
    }    
}

class RangeIterable {
    public var start:Int;
    public var end:Int;

    public function new(start:Int, end:Int) {
        this.start = start;
        this.end = end;
    }

    public function iterator():Iterator<Int> {
        var current:Int = start;

        return {
            hasNext: function():Bool {
                return current <= end;
            },
            next: function():Int {
                return current++;
            }
        };
    }
}

class ArrayLiteralExpression extends Expression {
    public var elements: Array<Expression>;
    
    public function new(elements: Array<Expression>) {
        this.elements = elements;
    }
    
    public override function evaluate(): Dynamic {
        var result: Array<Dynamic> = [];
        for (element in elements) {
            result.push(element.evaluate());
        }
        return result;
    }
}

class FuncStatement extends Statement {
    public var name:String;
    public var parameters:Array<Parameter>;
    public var body:BlockStatement;

    public function new(name:String, parameters:Array<Parameter>, body:BlockStatement) {
        this.name = name;
        this.parameters = parameters;
        this.body = body;
    }

    public override function execute():Void {
        var func = new Function(name, parameters, body);
        Environment.defineFunction(name, func);
    }
}

class CallStatement extends Statement {
    public var name:String;
    public var arguments:Array<Expression>;

    public function new(name:String, arguments:Array<Expression>) {
        this.name = name;
        this.arguments = arguments;
    }

    public override function execute():Void {
        var func:Function = Environment.getFunction(name);
        if (func == null) {
            Flow.error.report("Unknown function: " + name);
            return;
        }
        var args:Array<Dynamic> = [];
        for (arg in arguments) {
            args.push(arg.evaluate());
        }
        func.execute(args);
    }
}

class Function {
    public var name:String;
    public var parameters:Array<Parameter>;
    public var body:BlockStatement;

    public function new(name:String, parameters:Array<Parameter>, body:BlockStatement) {
        this.name = name;
        this.parameters = parameters;
        this.body = body;
    }

    public function execute(args:Array<Dynamic>):Dynamic {
        var oldValues:Map<String, Dynamic> = Environment.values.copy();
        for (i in 0...parameters.length) {
            if (i < args.length) {
                Environment.define(parameters[i].name, args[i]);
            } else if (parameters[i].defaultValue != null) {
                Environment.define(parameters[i].name, parameters[i].defaultValue.evaluate());
            } else {
                Flow.error.report("Missing argument for parameter '" + parameters[i].name + "'");
                return null;
            }
        }

        try {
            body.execute();
            Environment.values = oldValues;
            return null;
        } catch (e:ReturnValue) {
            Environment.values = oldValues;
            return e.value;
        }
    }
}

class CallExpression extends Expression {
    public var name:String;
    public var arguments:Array<Expression>;

    public function new(name:String, arguments:Array<Expression>) {
        this.name = name;
        this.arguments = arguments;
    }

    public override function evaluate():Dynamic {
        var func:Function = Environment.getFunction(name);
        if (func == null) {
            Flow.error.report("Undefined function: " + name);
            return null;
        }

        var args:Array<Dynamic> = [];
        for (arg in arguments) {
            args.push(arg.evaluate());
        }

        try {
            return func.execute(args);
        } catch (e:ReturnValue) {
            return e.value;
        }
    }
}

class FunctionLiteralExpression extends Expression {
    public var parameters:Array<Parameter>;
    public var body:BlockStatement;

    public function new(parameters:Array<Parameter>, body:BlockStatement) {
        this.parameters = parameters;
        this.body = body;
    }

    public override function evaluate():Dynamic {
        return new Function(null, parameters, body);
    }
}

class MethodCallExpression extends Expression {
    public var objectName: String;
    public var methodName: String;
    public var arguments: Array<Expression>;

    public function new(objectName: String, methodName: String, arguments: Array<Expression>) {
        this.objectName = objectName;
        this.methodName = methodName;
        this.arguments = arguments;
    }

    public override function evaluate(): Dynamic {
        var obj: Dynamic = Environment.get(objectName);
        if (obj == null) {
            Flow.error.report("Undefined object: " + objectName);
            return null;
        }

        var func: Dynamic = Environment.getFunction(methodName, obj);
        if (func == null || !(func is Function)) {
            Flow.error.report("Undefined method: " + methodName);
            return null;
        }

        var args: Array<Dynamic> = [];
        for (arg in arguments) {
            args.push(arg.evaluate());
        }

        try {
            return func.execute(args);
        } catch (e:ReturnValue) {
            return e.value;
        }
    }
}

class MethodCallStatement extends Statement {
    public var objectName: String;
    public var methodName: String;
    public var arguments: Array<Expression>;

    public function new(objectName: String, methodName: String, arguments: Array<Expression>) {
        this.objectName = objectName;
        this.methodName = methodName;
        this.arguments = arguments;
    }

    public override function execute():Void {
        var obj: Dynamic = Environment.get(objectName);
        if (obj == null) {
            Flow.error.report("Undefined object: " + objectName);
            return;
        }

        var func: Dynamic = Environment.getFunction(methodName, obj);
        if (func == null || !(func is Function)) {
            Flow.error.report("Undefined method: " + methodName);
            return;
        }

        var args: Array<Dynamic> = [];
        for (arg in arguments) {
            args.push(arg.evaluate());
        }
        func.execute(args);
    }
}

class Parameter {
    public var name:String;
    public var defaultValue:Expression;

    public function new(name:String, defaultValue:Expression = null) {
        this.name = name;
        this.defaultValue = defaultValue;
    }
}

class ReturnStatement extends Statement {
    public var expression:Expression;

    public function new(expression:Expression) {
        this.expression = expression;
    }

    public override function execute():Void {
        throw new ReturnValue(expression.evaluate());
    }
}

class ReturnValue extends haxe.Exception {
    public var value:Dynamic;

    public function new(value:Dynamic) {
        this.value = value;
        super('');
    }
}

class ObjectExpression extends Expression {
    public var properties:Map<String, Expression>;

    public function new(properties:Map<String, Expression>) {
        this.properties = properties;
    }

    public override function evaluate():Dynamic {
        var obj:Dynamic = {};
        for (key in properties.keys()) {
            Reflect.setField(obj, key, properties[key].evaluate());
        }
        return obj;
    }
}

class PropertyAccessExpression extends Expression {
    public var obj:Expression;
    public var property:String;

    public function new(obj:Expression, property:String) {
        this.obj = obj;
        this.property = property;
    }

    public override function evaluate():Dynamic {
        var objValue:Dynamic = obj.evaluate();

        if (property == "length") {
            if (Std.is(objValue, String) || Std.is(objValue, Array)) {
                return objValue.length;
            } else {
                Flow.error.report("Cannot access 'length' property on non-array/non-string.");
                return null;
            }
        }

        if (objValue != null && Reflect.hasField(objValue, property)) {
            return Reflect.field(objValue, property);
        } else {
            Flow.error.report("Property '" + property + "' does not exist on object.");
            return null;
        }
    }
}

class ArrayAccessExpression extends Expression {
    public var array:Expression;
    public var index:Expression;

    public function new(array:Expression, index:Expression) {
        this.array = array;
        this.index = index;
    }

    public override function evaluate():Dynamic {
        var arrayValue:Array<Dynamic> = array.evaluate();
        var indexValue:Int = index.evaluate();

        if (arrayValue == null) {
            Flow.error.report("Cannot access element of null array");
            return null;
        }

        if (indexValue < 0 || indexValue >= arrayValue.length) {
            Flow.error.report("Index out of bounds: " + indexValue);
            return null;
        }

        return arrayValue[indexValue];
    }
}

class ArrayAssignmentStatement extends Statement {
    public var arrayName:String;
    public var index:Expression;
    public var value:Expression;

    public function new(arrayName:String, index:Expression, value:Expression) {
        this.arrayName = arrayName;
        this.index = index;
        this.value = value;
    }

    public override function execute():Void {
        var arrayValue:Array<Dynamic> = Environment.get(arrayName);
        if (arrayValue == null) {
            Flow.error.report("Undefined array: " + arrayName);
            return;
        }

        var indexValue:Int = index.evaluate();
        if (indexValue < 0 || indexValue >= arrayValue.length) {
            Flow.error.report("Index out of bounds: " + indexValue);
            return;
        }

        arrayValue[indexValue] = value.evaluate();
        Environment.define(arrayName, arrayValue);
    }
}

class BreakStatement extends Statement {
    public function new() {}

    public override function execute():Void {
        throw new BreakException();
    }
}

class BreakException extends haxe.Exception {
    public function new() {
        super('Break');
    }
}

class ContinueStatement extends Statement {
    public function new() {}

    public override function execute():Void {
        throw new ContinueException();
    }
}

class ContinueException extends haxe.Exception {
    public function new() {
        super('Continue');
    }
}

class SwitchStatement extends Statement {
    public var expression:Expression;
    public var cases:Array<CaseClause>;
    public var defaultClause:DefaultClause;

    public function new(expression:Expression, cases:Array<CaseClause>, defaultClause:DefaultClause) {
        this.expression = expression;
        this.cases = cases;
        this.defaultClause = defaultClause;
    }

    public override function execute():Void {
        var switchValue = expression.evaluate();
        var executed = false;

        for (caseClause in cases) {
            if (caseClause.caseValue.evaluate() == switchValue) {
                caseClause.caseBody.execute();
                executed = true;
                if (!caseClause.fallsThrough) break;
            }
        }

        if (!executed && defaultClause != null) {
            defaultClause.defaultBody.execute();
        }
    }
}

class CaseClause {
    public var caseValue:Expression;
    public var caseBody:BlockStatement;
    public var fallsThrough:Bool;

    public function new(caseValue:Expression, caseBody:BlockStatement, fallsThrough:Bool) {
        this.caseValue = caseValue;
        this.caseBody = caseBody;
        this.fallsThrough = fallsThrough;
    }
}

class DefaultClause {
    public var defaultBody:BlockStatement;

    public function new(defaultBody:BlockStatement) {
        this.defaultBody = defaultBody;
    }
}

class ImportStatement extends Statement {
    public var scriptFile:String;

    public function new(scriptFile:String) {
        this.scriptFile = scriptFile;
    }

    public override function execute():Void {
        var scriptPath = getScriptPath();
        if (!sys.FileSystem.exists(scriptPath)) {
            Flow.error.report('Script file "$scriptPath" does not exist.');
        }
        var code = sys.io.File.getContent(scriptPath);
        var tokens:Array<flow.Lexer.Token> = Lexer.tokenize(code);
        var parser:Parser = new Parser(tokens);
        var program:Program = parser.parse();
        program.execute();
    }

    private function getScriptPath():String {
        if (sys.FileSystem.exists("project.json")) {
            var jsonData = sys.io.File.getContent("project.json");
            var projectData:Dynamic = Json.parse(jsonData);
            return projectData.src + "/" + scriptFile;
        } else {
            return scriptFile;
        }
    }
}

class ChrFunctionCall extends Expression {
    public var argument: Expression;

    public function new(argument: Expression) {
        this.argument = argument;
    }

    public override function evaluate(): Dynamic {
        var code = Std.int(argument.evaluate());
        return String.fromCharCode(code);
    }
}

class FillFunctionCall extends Expression {
    public var size:Expression;
    public var value:Expression;

    public function new(size:Expression, value:Expression) {
        this.size = size;
        this.value = value;
    }

    public override function evaluate():Dynamic {
        var sizeValue = size.evaluate();
        var valueValue = value.evaluate();

        if (Std.is(sizeValue, Int) && Std.is(valueValue, Int)) {
            var intSize = cast(sizeValue, Int);
            var intValue = cast(valueValue, Int);

            if (intSize < 0) {
                Flow.error.report("Size cannot be negative.");
                return [];
            }

            var result:Array<Dynamic> = [];
            for (i in 0...intSize) {
                result.push(intValue);
            }
            return result;
        } else {
            Flow.error.report("Arguments to 'fill' must be integers.");
            return [];
        }
    }
}

class CharAtFunctionCall extends Expression {
    public var stringExpr: Expression;
    public var indexExpr: Expression;

    public function new(stringExpr: Expression, indexExpr: Expression) {
        this.stringExpr = stringExpr;
        this.indexExpr = indexExpr;
    }

    public override function evaluate(): Dynamic {
        var strValue = stringExpr.evaluate();
        var indexValue = indexExpr.evaluate();

        var index = Std.int(indexValue);
        var str = cast(strValue, String);

        if (index < 0 || index >= str.length) {
            Flow.error.report("Index out of bounds: " + index);
            return "";
        }

        return str.charAt(index);
    }
}

class CharCodeAtFunctionCall extends Expression {
    public var stringExpr:Expression;
    public var indexExpr:Expression;

    public function new(stringExpr:Expression, indexExpr:Expression) {
        this.stringExpr = stringExpr;
        this.indexExpr = indexExpr;
    }

    public override function evaluate():Dynamic {
        var str = stringExpr.evaluate();
        var index = indexExpr.evaluate();
        if (Std.is(str, String) && Std.is(index, Int)) {
            return str.charCodeAt(index);
        }
        return null;
    }
}

class PushStatement extends Statement {
    public var array: Expression;
    public var value: Expression;

    public function new(array: Expression, value: Expression) {
        this.array = array;
        this.value = value;
    }

    public override function execute(): Void {
        var arrayValue: Array<Dynamic> = array.evaluate();
        var valueEvaluated: Dynamic = value.evaluate();

        if (arrayValue == null) {
            Flow.error.report("Cannot push to null array");
            return;
        }

        arrayValue.push(valueEvaluated);
    }
}

class PopStatement extends Statement {
    public var array: Expression;
    public var variable: String;

    public function new(array: Expression, variable: String) {
        this.array = array;
        this.variable = variable;
    }

    public override function execute(): Void {
        var arrayValue: Array<Dynamic> = array.evaluate();

        if (arrayValue == null) {
            Flow.error.report("Cannot pop from null array");
            return;
        }

        if (arrayValue.length == 0) {
            Flow.error.report("Cannot pop from empty array");
            return;
        }

        var poppedValue: Dynamic = arrayValue.pop();
        Environment.define(variable, poppedValue);
    }
}

class PushFunctionCall extends Expression {
    public var array: Expression;
    public var value: Expression;

    public function new(array: Expression, value: Expression) {
        this.array = array;
        this.value = value;
    }

    public override function evaluate(): Dynamic {
        var arrayValue: Array<Dynamic> = array.evaluate();
        var valueEvaluated: Dynamic = value.evaluate();

        if (arrayValue == null) {
            Flow.error.report("Cannot push to null array");
            return null;
        }

        arrayValue.push(valueEvaluated);
        return valueEvaluated;
    }
}

class PopFunctionCall extends Expression {
    public var array: Expression;
    public var value: String;

    public function new(array: Expression, value: String) {
        this.array = array;
        this.value = value;
    }

    public override function evaluate(): Dynamic {
        var arrayValue: Array<Dynamic> = array.evaluate();

        if (arrayValue == null) {
            Flow.error.report("Cannot pop from null array");
            return null;
        }

        if (arrayValue.length == 0) {
            Flow.error.report("Cannot pop from empty array");
            return null;
        }

        var poppedValue: Dynamic = arrayValue.pop();
        Environment.define(value, poppedValue);

        return poppedValue;
    }
}

class StrFunctionCall extends Expression {
    public var argument: Expression;

    public function new(argument: Expression) {
        this.argument = argument;
    }

    public override function evaluate(): Dynamic {
        var value = argument.evaluate();
        return Std.string(value);
    }
}

class SubstringFunctionCall extends Expression {
    public var stringExpr: Expression;
    public var startExpr: Expression;
    public var endExpr: Expression;

    public function new(stringExpr: Expression, startExpr: Expression, endExpr: Expression = null) {
        this.stringExpr = stringExpr;
        this.startExpr = startExpr;
        this.endExpr = endExpr;
    }

    public override function evaluate(): Dynamic {
        var strValue = stringExpr.evaluate();
        var startValue = startExpr.evaluate();
        var str = cast(strValue, String);
        var start = Std.int(startValue);

        var end = endExpr != null ? Std.int(endExpr.evaluate()) : str.length;
        
        if (start < 0 || start > str.length || end < 0 || end > str.length || start > end) {
            Flow.error.report("Invalid substring range: " + start + " to " + end);
            return "";
        }

        return str.substring(start, end);
    }
}

class ToUpperCaseFunctionCall extends Expression {
    public var argument: Expression;

    public function new(argument: Expression) {
        this.argument = argument;
    }

    public override function evaluate(): Dynamic {
        var strValue = argument.evaluate();
        var str = cast(strValue, String);

        return str.toUpperCase();
    }
}

class ToLowerCaseFunctionCall extends Expression {
    public var argument: Expression;

    public function new(argument: Expression) {
        this.argument = argument;
    }

    public override function evaluate(): Dynamic {
        var strValue = argument.evaluate();
        var str = cast(strValue, String);

        return str.toLowerCase();
    }
}

class JoinFunctionCall extends Expression {
    public var arrayExpr: Expression;
    public var delimiterExpr: Expression;

    public function new(arrayExpr: Expression, delimiterExpr: Expression = null) {
        this.arrayExpr = arrayExpr;
        this.delimiterExpr = delimiterExpr;
    }

    public override function evaluate(): Dynamic {
        var arrayValue = arrayExpr.evaluate();
        var array = cast(arrayValue, Array<Dynamic>);

        var delimiter = delimiterExpr != null ? cast(delimiterExpr.evaluate(), String) : "";
        
        return array.join(delimiter);
    }
}

class SplitFunctionCall extends Expression {
    public var stringExpr: Expression;
    public var delimiterExpr: Expression;

    public function new(stringExpr: Expression, delimiterExpr: Expression) {
        this.stringExpr = stringExpr;
        this.delimiterExpr = delimiterExpr;
    }

    public override function evaluate(): Dynamic {
        var strValue = stringExpr.evaluate();
        var delimiterValue = delimiterExpr.evaluate();

        var str = cast(strValue, String);
        var delimiter = cast(delimiterValue, String);

        return str.split(delimiter);
    }
}

class ParseNumberFunctionCall extends Expression {
    public var argument: Expression;

    public function new(argument: Expression) {
        this.argument = argument;
    }

    public override function evaluate(): Dynamic {
        var argValue = argument.evaluate();
        var str = cast(argValue, String);
        return Std.parseFloat(str);
    }
}

class ReplaceFunctionCall extends Expression {
    public var stringExpr: Expression;
    public var targetExpr: Expression;
    public var replacementExpr: Expression;

    public function new(stringExpr: Expression, targetExpr: Expression, replacementExpr: Expression) {
        this.stringExpr = stringExpr;
        this.targetExpr = targetExpr;
        this.replacementExpr = replacementExpr;
    }

    public override function evaluate(): Dynamic {
        var strValue = stringExpr.evaluate();
        var targetValue = targetExpr.evaluate();
        var replacementValue = replacementExpr.evaluate();

        var str = cast(strValue, String);
        var target = cast(targetValue, String);
        var replacement = cast(replacementValue, String);

        return str.split(target).join(replacement);
    }
}

class ConcatFunctionCall extends Expression {
    public var firstExpr: Expression;
    public var secondExpr: Expression;

    public function new(firstExpr: Expression, secondExpr: Expression) {
        this.firstExpr = firstExpr;
        this.secondExpr = secondExpr;
    }

    public override function evaluate(): Dynamic {
        var firstValue = firstExpr.evaluate();
        var secondValue = secondExpr.evaluate();

        switch (Type.typeof(firstValue)) {
            case TClass(String):
                var firstStr = cast(firstValue, String);
                var secondStr = cast(secondValue, String);
                return firstStr + secondStr;
            case TClass(Array):
                var firstArr = cast(firstValue, Array<Dynamic>);
                var secondArr = cast(secondValue, Array<Dynamic>);
                return firstArr.concat(secondArr);
            default:
                throw "Concat can only be applied to strings or arrays.";
        }
    }
}

class IndexOfFunctionCall extends Expression {
    public var stringExpr: Expression;
    public var searchExpr: Expression;

    public function new(stringExpr: Expression, searchExpr: Expression) {
        this.stringExpr = stringExpr;
        this.searchExpr = searchExpr;
    }

    public override function evaluate(): Dynamic {
        var strValue = stringExpr.evaluate();
        var searchValue = searchExpr.evaluate();

        switch (Type.typeof(strValue)) {
            case TClass(String):
                var str = cast(strValue, String);
                var search = cast(searchValue, String);
                return str.indexOf(search);
            case TClass(Array):
                var arr = cast(strValue, Array<Dynamic>);
                var searchItem = searchValue;
                return arr.indexOf(searchItem);
            default:
                throw "IndexOf can only be applied to strings or arrays.";
        }
    }
}

class ToStringFunctionCall extends Expression {
    public var argument: Expression;

    public function new(argument: Expression) {
        this.argument = argument;
    }

    public override function evaluate(): Dynamic {
        var argValue = argument.evaluate();
        return Std.string(argValue);
    }
}

class TrimFunctionCall extends Expression {
    public var argument: Expression;

    public function new(argument: Expression) {
        this.argument = argument;
    }

    public override function evaluate(): Dynamic {
        var argValue = argument.evaluate();
        var arg = cast(argValue, String);
        return arg.trim();
    }
}

class StartsWithFunctionCall extends Expression {
    public var stringOrArrayExpr: Expression;
    public var searchExpr: Expression;

    public function new(stringOrArrayExpr: Expression, searchExpr: Expression) {
        this.stringOrArrayExpr = stringOrArrayExpr;
        this.searchExpr = searchExpr;
    }

    public override function evaluate(): Dynamic {
        var strOrArrValue = stringOrArrayExpr.evaluate();
        var searchValue = searchExpr.evaluate();

        switch (Type.typeof(strOrArrValue)) {
            case TClass(String):
                var str = cast(strOrArrValue, String);
                var searchStr = cast(searchValue, String);
                return str.indexOf(searchStr) == 0;
            case TClass(Array):
                var arr = cast(strOrArrValue, Array<Dynamic>);
                return arr.length > 0 && arr[0] == searchValue;
            default:
                throw "StartsWith can only be applied to strings or arrays.";
        }
    }
}

class EndsWithFunctionCall extends Expression {
    public var stringOrArrayExpr: Expression;
    public var searchExpr: Expression;

    public function new(stringOrArrayExpr: Expression, searchExpr: Expression) {
        this.stringOrArrayExpr = stringOrArrayExpr;
        this.searchExpr = searchExpr;
    }

    public override function evaluate(): Dynamic {
        var strOrArrValue = stringOrArrayExpr.evaluate();
        var searchValue = searchExpr.evaluate();

        switch (Type.typeof(strOrArrValue)) {
            case TClass(String):
                var str = cast(strOrArrValue, String);
                var searchStr = cast(searchValue, String);
                return str.lastIndexOf(searchStr) == str.length - searchStr.length;
            case TClass(Array):
                var arr = cast(strOrArrValue, Array<Dynamic>);
                return arr.length > 0 && arr[arr.length - 1] == searchValue;
            default:
                throw "EndsWith can only be applied to strings or arrays.";
        }
    }
}

class SliceFunctionCall extends Expression {
    public var stringOrArrayExpr: Expression;
    public var startExpr: Expression;
    public var endExpr: Expression;

    public function new(stringOrArrayExpr: Expression, startExpr: Expression, endExpr: Expression) {
        this.stringOrArrayExpr = stringOrArrayExpr;
        this.startExpr = startExpr;
        this.endExpr = endExpr;
    }

    public override function evaluate(): Dynamic {
        var strOrArrValue = stringOrArrayExpr.evaluate();
        var startValue = startExpr.evaluate();
        var endValue = endExpr.evaluate();

        var start = cast(startValue, Int);
        var end = cast(endValue, Int);

        switch (Type.typeof(strOrArrValue)) {
            case TClass(String):
                var str = cast(strOrArrValue, String);
                return str.substring(start, end);
            case TClass(Array):
                var arr = cast(strOrArrValue, Array<Dynamic>);
                return arr.slice(start, end);
            default:
                throw "Slice can only be applied to strings or arrays.";
        }
    }
}

class SetFunctionCall extends Expression {
    public var targetExpr: Expression;
    public var keyExpr: Expression;
    public var valueExpr: Expression;

    public function new(targetExpr: Expression, keyExpr: Expression, valueExpr: Expression) {
        this.targetExpr = targetExpr;
        this.keyExpr = keyExpr;
        this.valueExpr = valueExpr;
    }

    public override function evaluate(): Dynamic {
        var targetValue = targetExpr.evaluate();
        var keyValue = keyExpr.evaluate();
        var valueValue = valueExpr.evaluate();

        switch (Type.typeof(targetValue)) {
            case TClass(Array):
                var arr = cast(targetValue, Array<Dynamic>);
                if (Std.is(keyValue, Int)) {
                    var index = cast(keyValue, Int);
                    arr[index] = valueValue;
                } else {
                    var key = cast(keyValue, String);
                    for (i in 0...arr.length) {
                        if (arr[i][0] == key) {
                            arr[i][1] = valueValue;
                            return valueValue;
                        }
                    }
                    arr.push([key, valueValue]);
                }
                return valueValue;
            case TObject:
                Reflect.setField(targetValue, cast(keyValue, String), valueValue);
                return valueValue;
            default:
                throw "Set can only be applied to arrays or objects.";
        }
    }
}

class GetFunctionCall extends Expression {
    public var targetExpr: Expression;
    public var keyExpr: Expression;

    public function new(targetExpr: Expression, keyExpr: Expression) {
        this.targetExpr = targetExpr;
        this.keyExpr = keyExpr;
    }

    public override function evaluate(): Dynamic {
        var targetValue = targetExpr.evaluate();
        var keyValue = keyExpr.evaluate();

        switch (Type.typeof(targetValue)) {
            case TClass(Array):
                var arr = cast(targetValue, Array<Dynamic>);
                if (Std.is(keyValue, Int)) {
                    var index = cast(keyValue, Int);
                    return arr[index];
                } else {
                    var key = cast(keyValue, String);
                    for (i in 0...arr.length) {
                        if (arr[i][0] == key) {
                            return arr[i][1];
                        }
                    }
                    return null;
                }
            case TObject:
                return Reflect.field(targetValue, cast(keyValue, String));
            default:
                throw "Get can only be applied to arrays or objects.";
        }
    }
}

class SetStatement extends Statement {
    public var targetExpr: Expression;
    public var keyExpr: Expression;
    public var valueExpr: Expression;

    public function new(targetExpr: Expression, keyExpr: Expression, valueExpr: Expression) {
        this.targetExpr = targetExpr;
        this.keyExpr = keyExpr;
        this.valueExpr = valueExpr;
    }

    public override function execute():Void {
        var targetValue = targetExpr.evaluate();
        var keyValue = keyExpr.evaluate();
        var valueValue = valueExpr.evaluate();

        switch (Type.typeof(targetValue)) {
            case TClass(Array):
                var arr = cast(targetValue, Array<Dynamic>);
                if (Std.is(keyValue, Int)) {
                    var index = cast(keyValue, Int);
                    arr[index] = valueValue;
                } else {
                    var key = cast(keyValue, String);
                    var found = false;
                    for (i in 0...arr.length) {
                        if (arr[i][0] == key) {
                            arr[i][1] = valueValue;
                            found = true;
                            break;
                        }
                    }
                    if (!found) {
                        arr.push([key, valueValue]);
                    }
                }
            case TObject:
                Reflect.setField(targetValue, cast(keyValue, String), valueValue);
            default:
                throw "Set can only be applied to arrays or objects.";
        }
    }
}

class GetStatement extends Statement {
    public var targetExpr: Expression;
    public var keyExpr: Expression;
    public var result: Dynamic;

    public function new(targetExpr: Expression, keyExpr: Expression) {
        this.targetExpr = targetExpr;
        this.keyExpr = keyExpr;
    }

    public override function execute():Void {
        var targetValue = targetExpr.evaluate();
        var keyValue = keyExpr.evaluate();

        switch (Type.typeof(targetValue)) {
            case TClass(Array):
                var arr = cast(targetValue, Array<Dynamic>);
                if (Std.is(keyValue, Int)) {
                    var index = cast(keyValue, Int);
                    if (index >= 0 && index < arr.length) {
                        result = arr[index];
                    } else {
                        result = null;
                    }
                } else {
                    var key = cast(keyValue, String);
                    for (i in 0...arr.length) {
                        if (arr[i][0] == key) {
                            result = arr[i][1];
                            return;
                        }
                    }
                    result = null;
                }
            case TObject:
                result = Reflect.field(targetValue, cast(keyValue, String));
            default:
                throw "Get can only be applied to arrays or objects.";
        }
    }
}

class IOExpression extends Expression {
    public var methodName:String;
    public var arguments:Array<Expression>;

    public function new(methodName:String, arguments:Array<Expression> = null) {
        this.methodName = methodName;
        this.arguments = arguments != null ? arguments : [];
    }

    public override function evaluate():Dynamic {
        var evaluatedArguments:Array<Dynamic> = [];
        for (argument in arguments) {
            evaluatedArguments.push(argument.evaluate());
        }

        switch (methodName) {
            case "print":
                IO.print(evaluatedArguments.join(" "));
                return null;
            case "println":
                IO.println(evaluatedArguments.join(" "));
                return null;
            case "readLine":
                return IO.readLine(evaluatedArguments.join(" "));
            case "writeByte":
                if (evaluatedArguments.length == 1) {
                    var byteValue = evaluatedArguments[0];
                    if (Std.is(byteValue, Int) && byteValue >= 0 && byteValue <= 255) {
                        IO.writeByte(byteValue);
                    } else {
                        Flow.error.report("Invalid byte value: " + byteValue);
                    }
                } else {
                    Flow.error.report("writeByte requires exactly one argument.");
                }
                return null;
        }

        return null;
    }
}

class IOStatement extends Statement {
    public var methodName:String;
    public var arguments:Array<Expression>;

    public function new(methodName:String, arguments:Array<Expression> = null) {
        this.methodName = methodName;
        this.arguments = arguments != null ? arguments : [];
    }

    public override function execute():Void {
        var evaluatedArguments:Array<Dynamic> = [];
        for (argument in arguments) {
            evaluatedArguments.push(argument.evaluate());
        }

        switch (methodName) {
            case "print":
                IO.print(evaluatedArguments.join(" "));
            case "println":
                IO.println(evaluatedArguments.join(" "));
            case "readLine":
                IO.readLine(evaluatedArguments.join(" "));
            case "writeByte":
                if (evaluatedArguments.length == 1) {
                    var byteValue = evaluatedArguments[0];
                    if (Std.is(byteValue, Int) && byteValue >= 0 && byteValue <= 255) {
                        IO.writeByte(byteValue);
                    } else {
                        Flow.error.report("Invalid byte value: " + byteValue);
                    }
                } else {
                    Flow.error.report("writeByte requires exactly one argument.");
                }
        }
    }
}

class RandomExpression extends Expression {
    public var methodName:String;
    public var arguments:Array<Expression>;

    public function new(methodName:String, arguments:Array<Expression>) {
        this.methodName = methodName;
        this.arguments = arguments;
    }

    public override function evaluate():Int {
        var min:Int = arguments[0].evaluate();
        var max:Int = arguments[1].evaluate();
        return Random.nextInt(min, max);
    }
}

class RandomStatement extends Statement {
    public var methodName:String;
    public var arguments:Array<Expression>;

    public function new(methodName:String, arguments:Array<Expression>) {
        this.methodName = methodName;
        this.arguments = arguments;
    }

    public override function execute():Void {
        var min:Int = arguments[0].evaluate();
        var max:Int = arguments[1].evaluate();
        Random.nextInt(min, max);
    }
}

class SystemExpression extends Expression {
    public var methodName:String;
    public var arguments:Array<Expression>;

    public function new(methodName:String, ?arguments:Array<Expression>) {
        this.methodName = methodName;
        this.arguments = arguments != null ? arguments : [];
    }

    public override function evaluate():Dynamic {
        var evaluatedArguments:Array<Dynamic> = [];
        for (argument in arguments) {
            evaluatedArguments.push(argument.evaluate());
        }

        switch (methodName) {
            case "println":
                System.println(evaluatedArguments.join(" "));
                return null;
            case "exit":
                System.exit();
                return null;
            case "currentDate":
                return System.currentDate();
            case "sleep":
                System.sleep(evaluatedArguments[0]);
                return null;
            case "openUrl":
                if (evaluatedArguments.length > 0) {
                    System.openUrl(evaluatedArguments[0]);
                }
                return null;
            case "command":
                if (evaluatedArguments.length > 0) {
                    System.command(evaluatedArguments[0]);
                }
                return null;
            case "systemName":
                return System.systemName();
        }

        return null;
    }
}

class SystemStatement extends Statement {
    public var methodName:String;
    public var arguments:Array<Expression>;

    public function new(methodName:String, ?arguments:Array<Expression>) {
        this.methodName = methodName;
        this.arguments = arguments != null ? arguments : [];
    }

    public override function execute():Void {
        var evaluatedArguments:Array<Dynamic> = [];
        for (argument in arguments) {
            evaluatedArguments.push(argument.evaluate());
        }

        switch (methodName) {
            case "println":
                System.println(evaluatedArguments.join(" "));
            case "exit":
                System.exit();
            case "currentDate":
                System.currentDate();
            case "sleep":
                System.sleep(evaluatedArguments[0]);
            case "openUrl":
                if (evaluatedArguments.length > 0) {
                    System.openUrl(evaluatedArguments[0]);
                }
            case "command":
                if (evaluatedArguments.length > 0) {
                    System.command(evaluatedArguments[0]);
                }
            case "systemName":
                System.systemName();
        }
    }
}

class FileExpression extends Expression {
    public var methodName:String;
    public var arguments:Array<Expression>;

    public function new(methodName:String, ?arguments:Array<Expression>) {
        this.methodName = methodName;
        this.arguments = arguments != null ? arguments : [];
    }

    public override function evaluate():Dynamic {
        var evaluatedArguments:Array<Dynamic> = [];
        for (argument in arguments) {
            evaluatedArguments.push(argument.evaluate());
        }

        switch (methodName) {
            case "readFile":
                return File.readFile(evaluatedArguments[0]);
            case "writeFile":
                File.writeFile(evaluatedArguments[0], evaluatedArguments[1]);
                return null;
            case "exists":
                return File.exists(evaluatedArguments[0]);
        }

        return null;
    }
}

class FileStatement extends Statement {
    public var methodName:String;
    public var arguments:Array<Expression>;

    public function new(methodName:String, arguments:Array<Expression>) {
        this.methodName = methodName;
        this.arguments = arguments != null ? arguments : [];
    }

    public override function execute():Void {
        var evaluatedArguments:Array<Dynamic> = [];
        for (argument in arguments) {
            evaluatedArguments.push(argument.evaluate());
        }

        switch (methodName) {
            case "readFile":
                File.readFile(evaluatedArguments[0]);
            case "writeFile":
                File.writeFile(evaluatedArguments[0], evaluatedArguments[1]);
            case "exists":
                File.exists(evaluatedArguments[0]);
        }
    }
}

class JsonExpression extends Expression {
    public var methodName:String;
    public var arguments:Array<Expression>;

    public function new(methodName:String, arguments:Array<Expression>) {
        this.methodName = methodName;
        this.arguments = arguments != null ? arguments : [];
    }

    public override function evaluate():Dynamic {
        var evaluatedArguments:Array<Dynamic> = [];
        for (argument in arguments) {
            evaluatedArguments.push(argument.evaluate());
        }

        switch (methodName) {
            case "parse":
                return Json.parse(evaluatedArguments[0]);
            case "stringify":
                return Json.stringify(evaluatedArguments[0]);
            case "isValid":
                return Json.isValid(evaluatedArguments[0]);
        }

        return null;
    }
}

class JsonStatement extends Statement {
    public var methodName:String;
    public var arguments:Array<Expression>;

    public function new(methodName:String, arguments:Array<Expression>) {
        this.methodName = methodName;
        this.arguments = arguments != null ? arguments : [];
    }

    public override function execute():Void {
        var evaluatedArguments:Array<Dynamic> = [];
        for (argument in arguments) {
            evaluatedArguments.push(argument.evaluate());
        }

        switch (methodName) {
            case "parse":
                Json.parse(evaluatedArguments[0]);
            case "stringify":
                Json.stringify(evaluatedArguments[0]);
            case "isValid":
                Json.isValid(evaluatedArguments[0]);
        }
    }
}

class MathExpression extends Expression {
    public var methodName:String;
    public var arguments:Array<Expression>;

    public function new(methodName:String, arguments:Array<Expression> = null) {
        this.methodName = methodName;
        this.arguments = arguments != null ? arguments : [];
    }

    public override function evaluate():Dynamic {
        var evaluatedArguments:Array<Dynamic> = [];
        for (argument in arguments) {
            evaluatedArguments.push(argument.evaluate());
        }

        switch (methodName) {
            case "getPI":
                return Math.getPI();
            case "abs":
                if (evaluatedArguments.length == 1) return Math.abs(evaluatedArguments[0]);
            case "max":
                if (evaluatedArguments.length == 2) return Math.max(evaluatedArguments[0], evaluatedArguments[1]);
            case "min":
                if (evaluatedArguments.length == 2) return Math.min(evaluatedArguments[0], evaluatedArguments[1]);
            case "pow":
                if (evaluatedArguments.length == 2) return Math.pow(evaluatedArguments[0], evaluatedArguments[1]);
            case "sqrt":
                if (evaluatedArguments.length == 1) return Math.sqrt(evaluatedArguments[0]);
            case "sin":
                if (evaluatedArguments.length == 1) return Math.sin(evaluatedArguments[0]);
            case "cos":
                if (evaluatedArguments.length == 1) return Math.cos(evaluatedArguments[0]);
            case "tan":
                if (evaluatedArguments.length == 1) return Math.tan(evaluatedArguments[0]);
            case "asin":
                if (evaluatedArguments.length == 1) return Math.asin(evaluatedArguments[0]);
            case "acos":
                if (evaluatedArguments.length == 1) return Math.acos(evaluatedArguments[0]);
            case "atan":
                if (evaluatedArguments.length == 1) return Math.atan(evaluatedArguments[0]);
            default:
                throw "Unknown method: " + methodName;
        }

        throw "Invalid arguments for method: " + methodName;
    }
}

class MathStatement extends Statement {
    public var methodName:String;
    public var arguments:Array<Expression>;

    public function new(methodName:String, arguments:Array<Expression> = null) {
        this.methodName = methodName;
        this.arguments = arguments != null ? arguments : [];
    }

    public override function execute():Void {
        var evaluatedArguments:Array<Dynamic> = [];
        for (argument in arguments) {
            evaluatedArguments.push(argument.evaluate());
        }

        switch (methodName) {
            case "getPI":
                Math.getPI();
            case "abs":
                if (evaluatedArguments.length == 1) Math.abs(evaluatedArguments[0]);
            case "max":
                if (evaluatedArguments.length == 2) Math.max(evaluatedArguments[0], evaluatedArguments[1]);
            case "min":
                if (evaluatedArguments.length == 2) Math.min(evaluatedArguments[0], evaluatedArguments[1]);
            case "pow":
                if (evaluatedArguments.length == 2) Math.pow(evaluatedArguments[0], evaluatedArguments[1]);
            case "sqrt":
                if (evaluatedArguments.length == 1) Math.sqrt(evaluatedArguments[0]);
            case "sin":
                if (evaluatedArguments.length == 1) Math.sin(evaluatedArguments[0]);
            case "cos":
                if (evaluatedArguments.length == 1) Math.cos(evaluatedArguments[0]);
            case "tan":
                if (evaluatedArguments.length == 1) Math.tan(evaluatedArguments[0]);
            case "asin":
                if (evaluatedArguments.length == 1) Math.asin(evaluatedArguments[0]);
            case "acos":
                if (evaluatedArguments.length == 1) Math.acos(evaluatedArguments[0]);
            case "atan":
                if (evaluatedArguments.length == 1) Math.atan(evaluatedArguments[0]);
            default:
                throw "Unknown method: " + methodName;
        }
    }
}
