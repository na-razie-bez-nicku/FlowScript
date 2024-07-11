package flow;

import flow.Lexer;
import flow.Program;
import logs.*;

class Parser {
    private var tokens:Array<Token>;
    private var currentTokenIndex:Int;

    public function new(tokens:Array<Token>) {
        this.tokens = tokens;
        this.currentTokenIndex = 0;
    }

    public function parse():Program {
        var statements:Array<Statement> = [];
        while (!isAtEnd()) {
            var statement:Statement = parseStatement();
            statements.push(statement);
        }
        return new Program(statements);
    }

    private function parseStatement():Statement {
        var firstTokenType:TokenType = peek().type;

        if (firstTokenType == TokenType.KEYWORD) {
            var keyword:String = advance().value;
            if (keyword == "print") {
                return parsePrintStatement();
            } else if (keyword == "let") {
                return parseLetStatement();
            } else if (keyword == "if") {
                return parseIfStatement();
            } else if (keyword == "while") {
                return parseWhileStatement();
            } else if (keyword == "for") {
                return parseForStatement();
            } else if (keyword == "func") {
                return parseFuncStatement();
            } else if (keyword == "call") {
                return parseCallStatement();
            } else if (keyword == "return") {
                return parseReturnStatement();
            } else {
                Flow.error.report("Unknown keyword: " + keyword);
                return null;
            }
        } else if (firstTokenType == TokenType.IO) {
            return parseIOStatement();
        } else if (firstTokenType == TokenType.RANDOM) {
            return parseRandomStatement();
        } else if (firstTokenType == TokenType.SYSTEM) {
            return parseSystemStatement();
        } else if (firstTokenType == TokenType.IDENTIFIER) {
            return parseLetStatement();
        } else {
            Flow.error.report("Unexpected token: " + peek().value);
            return null;
        }
    }

    private function parseLetStatement(): LetStatement {
        var nameToken: Token = consume(TokenType.IDENTIFIER, "Expected variable name after 'let'");
        var name: String = nameToken.value;
    
        consume(TokenType.EQUAL, "Expected '=' after variable name");
    
        var initializer: Expression;

        if (check(TokenType.LBRACKET)) {
            initializer = parseArrayLiteral();
        } else if (check(TokenType.LBRACE)) {
            initializer = parseObjectLiteral();
        } else if (check(TokenType.IO)) {
            initializer = parseIOExpression();
        } else if (check(TokenType.RANDOM)) {
            initializer = parseRandomExpression();
        } else if (check(TokenType.SYSTEM)) {
            initializer = parseSystemExpression();
        } else {
            initializer = parseExpression();
        }

        return new LetStatement(name, initializer);
    }

    private function parseArrayLiteral(): Expression {
        consume(TokenType.LBRACKET, "Expected '[' to start array literal");
    
        var elements: Array<Expression> = [];
    
        while (!check(TokenType.RBRACKET) && !isAtEnd()) {
            var element: Expression = parseExpression();
            elements.push(element);
    
            if (match([TokenType.COMMA])) {
                if (check(TokenType.RBRACKET)) {
                    break;
                }
            }
        }
    
        consume(TokenType.RBRACKET, "Expected ']' after array literal");
    
        return new ArrayLiteralExpression(elements);
    }

    private function parseObjectLiteral():Expression {
        var properties:Map<String, Expression> = new Map();
        consume(TokenType.LBRACE, "Expected '{' to start object literal");
        while (!check(TokenType.RBRACE)) {
            var key:Token = consume(TokenType.IDENTIFIER, "Expected property name");
            consume(TokenType.COLON, "Expected ':' after property name");
            var value:Expression = parseExpression();
            properties[key.value] = value;
            if (match([TokenType.COMMA])) {
                // Consume comma
            }
        }
        consume(TokenType.RBRACE, "Expected '}' after object literal");
        return new ObjectExpression(properties);
    }

    private function parsePrintStatement():PrintStatement {
        consume(TokenType.LPAREN, "Expected '(' after 'print'");
        var expression:Expression = parseExpression();
        consume(TokenType.RPAREN, "Expected ')' after expression");
        return new PrintStatement(expression);
    }

    private function parseIfStatement():Statement {
        var condition:Expression = parseExpression();
        var thenBranch:Statement = parseBlock();
        var elseBranch:Statement = null;

        if (match([TokenType.KEYWORD])) {
            var keyword:String = previous().value;
            if (keyword == "else") {
                if (peek().type == TokenType.KEYWORD && peek().value == "if") {
                    advance();
                    elseBranch = parseIfStatement();
                } else {
                    elseBranch = parseBlock();
                }
            }
        }

        return new IfStatement(condition, thenBranch, elseBranch);
    }

    private function parseWhileStatement():Statement {
        var condition:Expression = parseExpression();
        var body:Statement = parseBlock();
        return new WhileStatement(condition, body);
    }

    private function parseForStatement():Statement {
        var variableToken:Token = consume(TokenType.IDENTIFIER, "Expected identifier after 'for'");
        var variableName:String = variableToken.value;
    
        consume(TokenType.IN, "Expected 'in' after identifier");
    
        var iterableExpression:Expression = parseExpression();
    
        var body:Statement;
        if (check(TokenType.LBRACE)) {
            body = parseBlock();
        } else {
            body = parseStatement();
        }
    
        return new ForStatement(variableName, iterableExpression, body);
    }

    private function parseFuncStatement():FuncStatement {
        var nameToken:Token = consume(TokenType.IDENTIFIER, "Expected function name after 'func'");
        var name:String = nameToken.value;

        consume(TokenType.LPAREN, "Expected '(' after function name");

        var parameters:Array<String> = [];
        while (!check(TokenType.RPAREN)) {
            var parameterToken:Token = consume(TokenType.IDENTIFIER, "Expected parameter name");
            parameters.push(parameterToken.value);
            if (match([TokenType.COMMA])) {
                // Consume comma
            }
        }
        consume(TokenType.RPAREN, "Expected ')' after parameters");

        var body:BlockStatement = parseBlock();

        return new FuncStatement(name, parameters, body);
    }

    private function parseCallStatement():Statement {
        var nameToken:Token = consume(TokenType.IDENTIFIER, "Expected function name after 'call'");
        var name:String = nameToken.value;
        var arguments:Array<Expression> = [];
        consume(TokenType.LPAREN, "Expected '(' after function name");
        while (!check(TokenType.RPAREN)) {
            arguments.push(parseExpression());
            if (match([TokenType.COMMA])) {
                // Consume comma
            }
        }
        consume(TokenType.RPAREN, "Expected ')' after arguments");
        return new CallStatement(name, arguments);
    }

    private function parseReturnStatement(): Statement {
        var expression:Expression = parseExpression();
        return new ReturnStatement(expression);
    }

    private function parseIOStatement():Statement {
        var ioToken:Token = advance();
        if (ioToken.type != TokenType.IO) {
            Flow.error.report("Expected 'IO' keyword");
            return null;
        }
        var lparenToken:Token = advance();
        if (lparenToken.type != TokenType.LPAREN) {
            Flow.error.report("Expected '('");
            return null;
        }
        var rparenToken:Token = advance();
        if (rparenToken.type != TokenType.RPAREN) {
            Flow.error.report("Expected ')'");
            return null;
        }
        var methodNameToken:Token = advance();
        var methodName:String = methodNameToken.value;
        if (methodName == ".readLine") {
            consume(TokenType.LPAREN, "Expected '(' after 'readLine'");
            consume(TokenType.RPAREN, "Expected ')' after 'readLine'");
            return new IOStatement("readLine");
        } else if (methodName == ".print") {
            consume(TokenType.LPAREN, "Expected '(' after 'print'");
            var expression:Expression = parseExpression();
            consume(TokenType.RPAREN, "Expected ')' after expression");
            return new IOStatement("print", [expression]);
        } else if (methodName == ".println") {
            consume(TokenType.LPAREN, "Expected '(' after 'println'");
            var expression:Expression = parseExpression();
            consume(TokenType.RPAREN, "Expected ')' after expression");
            return new IOStatement("println", [expression]);
        } else {
            Flow.error.report("Unknown IO method: " + methodName);
            return null;
        }
    }

    private function parseRandomStatement():Statement {
        var randomToken:Token = advance();
        if (randomToken.type != TokenType.RANDOM) {
            Flow.error.report("Expected 'Random' keyword");
            return null;
        }

        var lparenToken:Token = advance();
        if (lparenToken.type != TokenType.LPAREN) {
            Flow.error.report("Expected '('");
            return null;
        }

        var rparenToken:Token = advance();
        if (rparenToken.type != TokenType.RPAREN) {
            Flow.error.report("Expected ')'");
            return null;
        }

        var methodNameToken:Token = advance();
        var methodName:String = methodNameToken.value;

        if (methodName == ".nextInt") {
            var lparenToken:Token = advance();
            if (lparenToken.type != TokenType.LPAREN) {
                Flow.error.report("Expected '(' after 'nextInt'");
                return null;
            }

            var minExpr:Expression = parseExpression();
            var commaToken:Token = advance();
            if (commaToken.type != TokenType.COMMA) {
                Flow.error.report("Expected ',' after min value");
                return null;
            }

            var maxExpr:Expression = parseExpression();
            var rparenToken:Token = advance();
            if (rparenToken.type != TokenType.RPAREN) {
                Flow.error.report("Expected ')' after max value");
                return null;
            }

            return new RandomStatement(methodName, [minExpr, maxExpr]);
        } else {
            Flow.error.report("Unknown random method: " + methodName);
            return null;
        }
    }

    private function parseSystemStatement():Statement {
        var randomToken:Token = advance();
        if (randomToken.type != TokenType.SYSTEM) {
            Flow.error.report("Expected 'System' keyword");
            return null;
        }

        var lparenToken:Token = advance();
        if (lparenToken.type != TokenType.LPAREN) {
            Flow.error.report("Expected '('");
            return null;
        }

        var rparenToken:Token = advance();
        if (rparenToken.type != TokenType.RPAREN) {
            Flow.error.report("Expected ')'");
            return null;
        }

        var methodNameToken:Token = advance();
        var methodName:String = methodNameToken.value;

        if (methodName == ".currentDate") {
            consume(TokenType.LPAREN, "Expected '(' after 'Date'");
            consume(TokenType.RPAREN, "Expected ')' after 'Date'");
            return new SystemStatement("currentDate");
        } else if (methodName == ".exit") {
            consume(TokenType.LPAREN, "Expected '(' after 'exit'");
            consume(TokenType.RPAREN, "Expected ')' after 'exit'");
            return new SystemStatement("exit");
        } else if (methodName == ".println") {
            consume(TokenType.LPAREN, "Expected '(' after 'println'");
            var expression:Expression = parseExpression();
            consume(TokenType.RPAREN, "Expected ')' after expression");
            return new SystemStatement("println", [expression]);
        } else {
            Flow.error.report("Unknown system method: " + methodName);
            return null;
        }
    }

    private function parseBlock(): BlockStatement {
        if (match([TokenType.LBRACE])) {
            var statements:Array<Statement> = [];
            while (!check(TokenType.RBRACE) && !isAtEnd()) {
                statements.push(parseStatement());
            }
            consume(TokenType.RBRACE, "Expected '}' after block");
            return new BlockStatement(statements);
        } else {
            var statement:Statement = parseStatement();
            return new BlockStatement([statement]);
        }
    }

    private function parseExpression():Expression {
        return parseEquality();
    }

    private function parseEquality():Expression {
        var expr = parseComparison();

        while (match([TokenType.EQUAL_EQUAL, TokenType.BANG_EQUAL])) {
            var opera = previous().value;
            var right = parseComparison();
            expr = new BinaryExpression(expr, opera, right);
        }

        return expr;
    }

    private function parseComparison(): Expression {
        var expr: Expression = parseTerm();
        while (match([TokenType.GREATER, TokenType.GREATER_EQUAL, TokenType.LESS, TokenType.LESS_EQUAL])) {
            var opera: String = previous().value;
            var right: Expression = parseTerm();
            expr = new BinaryExpression(expr, opera, right);
        }
        return expr;
    }
    
    private function parseTerm(): Expression {
        var expr: Expression = parseFactor();
        while (match([TokenType.PLUS, TokenType.MINUS, TokenType.MULTIPLY, TokenType.DIVIDE, TokenType.BITWISE_AND, TokenType.BITWISE_OR, TokenType.BITWISE_XOR])) {
            var opera: String = previous().value;
            var right: Expression = parseFactor();
            expr = new BinaryExpression(expr, opera, right);
        }
        return expr;
    }

    private function parseFactor():Expression {
        if (match([TokenType.NUMBER])) {
            var value:String = previous().value;
            if (value.indexOf(".") != -1) {
              return new LiteralExpression(Std.parseFloat(value));
            } else {
              return new LiteralExpression(Std.parseInt(value));
            }
        } else if (match([TokenType.STRING])) {
            return new LiteralExpression(previous().value);
        } else if (match([TokenType.IDENTIFIER])) {
            var identifier = previous().type;
            if (identifier == TokenType.IO) {
                return parseIOExpression();
            } else if (identifier == TokenType.RANDOM) {
                return parseRandomExpression();
            } else if (identifier == TokenType.SYSTEM) {
                return parseSystemExpression();
            } else {
                if (peek().type == TokenType.LPAREN) {
                    return parseCallExpression();
                } else {
                    return parsePropertyAccess();
                }
            }
        } else if (match([TokenType.TRUE])) {
            return new LiteralExpression(true);
        } else if (match([TokenType.FALSE])) {
            return new LiteralExpression(false);
        } else if (match([TokenType.LPAREN])) {
            var expr:Expression = parseExpression();
            consume(TokenType.RPAREN, "Expected ')' after expression");
            return expr;
        } else {
            Flow.error.report("Unexpected token: " + peek().value);
            return null;
        }
    }

    private function parseIOExpression():Expression {
        var ioToken:Token = advance();
        if (ioToken.type != TokenType.IO) {
            Flow.error.report("Expected 'IO' keyword");
            return null;
        }
        var lparenToken:Token = advance();
        if (lparenToken.type != TokenType.LPAREN) {
            Flow.error.report("Expected '('");
            return null;
        }
        var rparenToken:Token = advance();
        if (rparenToken.type != TokenType.RPAREN) {
            Flow.error.report("Expected ')'");
            return null;
        }
        var methodNameToken:Token = advance();
        var methodName:String = methodNameToken.value;
        if (methodName == ".readLine") {
            consume(TokenType.LPAREN, "Expected '(' after 'readLine'");
            consume(TokenType.RPAREN, "Expected ')' after 'readLine'");
            return new IOExpression("readLine");
        } else if (methodName == ".print") {
            consume(TokenType.LPAREN, "Expected '(' after 'print'");
            var expression:Expression = parseExpression();
            consume(TokenType.RPAREN, "Expected ')' after expression");
            return new IOExpression("print", [expression]);
        } else if (methodName == ".println") {
            consume(TokenType.LPAREN, "Expected '(' after 'println'");
            var expression:Expression = parseExpression();
            consume(TokenType.RPAREN, "Expected ')' after expression");
            return new IOExpression("println", [expression]);
        } else {
            Flow.error.report("Unknown IO method: " + methodName);
            return null;
        }
    }

    private function parseRandomExpression():Expression {
        var randomToken:Token = advance();
        if (randomToken.type != TokenType.RANDOM) {
            Flow.error.report("Expected 'Random' keyword");
            return null;
        }

        var lparenToken:Token = advance();
        if (lparenToken.type != TokenType.LPAREN) {
            Flow.error.report("Expected '('");
            return null;
        }

        var rparenToken:Token = advance();
        if (rparenToken.type != TokenType.RPAREN) {
            Flow.error.report("Expected ')'");
            return null;
        }

        var methodNameToken:Token = advance();
        var methodName:String = methodNameToken.value;

        if (methodName == ".nextInt") {
            var lparenToken:Token = advance();
            if (lparenToken.type != TokenType.LPAREN) {
                Flow.error.report("Expected '(' after 'nextInt'");
                return null;
            }

            var minExpr:Expression = parseExpression();
            var commaToken:Token = advance();
            if (commaToken.type != TokenType.COMMA) {
                Flow.error.report("Expected ',' after min value");
                return null;
            }

            var maxExpr:Expression = parseExpression();
            var rparenToken:Token = advance();
            if (rparenToken.type != TokenType.RPAREN) {
                Flow.error.report("Expected ')' after max value");
                return null;
            }

            return new RandomExpression(methodName, [minExpr, maxExpr]);
        } else {
            Flow.error.report("Unknown random method: " + methodName);
            return null;
        }
    }

    private function parseSystemExpression():Expression {
        var randomToken:Token = advance();
        if (randomToken.type != TokenType.SYSTEM) {
            Flow.error.report("Expected 'System' keyword");
            return null;
        }

        var lparenToken:Token = advance();
        if (lparenToken.type != TokenType.LPAREN) {
            Flow.error.report("Expected '('");
            return null;
        }

        var rparenToken:Token = advance();
        if (rparenToken.type != TokenType.RPAREN) {
            Flow.error.report("Expected ')'");
            return null;
        }

        var methodNameToken:Token = advance();
        var methodName:String = methodNameToken.value;

        if (methodName == ".currentDate") {
            consume(TokenType.LPAREN, "Expected '(' after 'Date'");
            consume(TokenType.RPAREN, "Expected ')' after 'Date'");
            return new SystemExpression("currentDate");
        } else if (methodName == ".exit") {
            consume(TokenType.LPAREN, "Expected '(' after 'exit'");
            consume(TokenType.RPAREN, "Expected ')' after 'exit'");
            return new SystemExpression("exit");
        } else if (methodName == ".println") {
            consume(TokenType.LPAREN, "Expected '(' after 'println'");
            var expression:Expression = parseExpression();
            consume(TokenType.RPAREN, "Expected ')' after expression");
            return new SystemExpression("println", [expression]);
        } else {
            Flow.error.report("Unknown system method: " + methodName);
            return null;
        }
    }

    private function parseCallExpression():Expression {
        var nameToken:Token = previous();
        var name:String = nameToken.value;
        var arguments:Array<Expression> = [];
        consume(TokenType.LPAREN, "Expected '(' after function name");
        while (!check(TokenType.RPAREN)) {
            arguments.push(parseExpression());
            if (match([TokenType.COMMA])) {
                // Consume comma
            }
        }
        consume(TokenType.RPAREN, "Expected ')' after arguments");
        return new CallExpression(name, arguments);
    }

    private function parsePropertyAccess():Expression {
        var obj:Expression = new VariableExpression(previous().value);
        while (match([TokenType.DOT])) {
            var property:Token = consume(TokenType.IDENTIFIER, "Expected property name");
            obj = new PropertyAccessExpression(obj, property.value);
        }
        return obj;
    }

    private function advance():Token {
        currentTokenIndex++;
        return previous();
    }

    private function isAtEnd():Bool {
        return currentTokenIndex >= tokens.length;
    }

    private function previous():Token {
        return tokens[currentTokenIndex - 1];
    }

    private function peek():Token {
        return tokens[currentTokenIndex];
    }

    private function match(tokenTypes:Array<TokenType>):Bool {
        for (tokenType in tokenTypes) {
            if (check(tokenType)) {
                advance();
                return true;
            }
        }
        return false;
    }

    private function check(tokenType:TokenType):Bool {
        if (isAtEnd()) return false;
        return peek().type == tokenType;
    }

    private function consume(tokenType:TokenType, message:String):Token {
        if (!check(tokenType)) {
            Flow.error.report(message);
        }
        return advance();
    }
}
