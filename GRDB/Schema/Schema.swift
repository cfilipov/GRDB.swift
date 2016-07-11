protocol BuilderType {
    func build(_ db: Database) throws -> String
}

protocol _SQLStringConvertible {
    var sql: String { get }
}

public class _CreateTableStatement: BuilderType {
    var temp: Bool
    var ifNotExists: Bool
    var name: String
    var columns: [_ColumnDef]
    var tableConstraints: [_TableConstraint] = []
    var withoutRowId: Bool
    var select: _SQLSelectable?

    private init(
        temp: Bool,
        ifNotExists: Bool,
        name: String,
        columns: [_ColumnDef],
        tableConstraints: [_TableConstraint],
        withoutRowId: Bool,
        select: _SQLSelectable?) {
        self.temp = temp
        self.ifNotExists = ifNotExists
        self.name = name
        self.columns = columns
        self.tableConstraints = tableConstraints
        self.withoutRowId = withoutRowId
        self.select = select
    }

    func build(_ db: Database) throws -> String {
        var parts = ["CREATE"]
        if temp {
            parts.append("TEMP")
        }
        parts.append("TABLE")
        if ifNotExists {
            parts.append("IF NOT EXISTS")
        }
        parts.append(name)
        guard columns.count > 0 else {
            throw DatabaseError(message: "Cannot create table with no columns")
        }
        parts.append("(")
        try parts.append(columns.build(db))
        for constraint in tableConstraints {
            parts.append(",")
            try parts.append(constraint.build(db))
        }
        parts.append(")")
        if ifNotExists {
            parts.append("WITHOUT ROWID")
        }
        return parts.joined(separator: " ")
    }

    @discardableResult public func column(_ column: SQLColumn, type: _SQLType? = nil) -> _ColumnDef {
        let columnDef = _ColumnDef(
            column,
            primaryKey: nil,
            type: type,
            notNullClause: nil,
            uniqueClause: nil,
            check: nil,
            defaults: nil,
            collate: nil,
            foreignKey: nil)
        columns.append(columnDef)
        return columnDef
    }

    @discardableResult public func foreignKey(
        columns: [SQLColumn],
        foreignTable: String,
        foreignColumns: SQLColumn...,
        onDelete: _DeleteUpdateAction? = nil,
        onUpdate: _DeleteUpdateAction? = nil,
        deferrable: Bool? = nil) -> _CreateTableStatement {
            tableConstraints.append(_ForeignKeyTableConstraint(
                columns: columns,
                foreignKey: _ForeignKeyClause(
                    table: foreignTable,
                    columns: foreignColumns,
                    onDelete: onDelete,
                    onUpdate: onUpdate,
                    deferrable: deferrable)))
        return self
    }

    @discardableResult public func primaryKey(
        columns: SQLColumn...,
        onConflict: _ConflictResolution = .abort) -> _CreateTableStatement {
        return self
    }

    @discardableResult public func unique(
        columns: SQLColumn...,
        onConflict: _ConflictResolution = .abort) -> _CreateTableStatement {
        return self
    }

    @discardableResult public func check(_ expr: _SQLExpressible) -> _CreateTableStatement {
        fatalError("UNIMPLEMENTED")
    }

    @discardableResult public func select(_ expr: _SQLSelectable) -> _CreateTableStatement {
        fatalError("UNIMPLEMENTED")
    }
}

public class _ColumnDef: BuilderType {
    private var column: SQLColumn
    private var primaryKey: _PrimaryKeyColumnConstraint?
    private var type: _SQLType?
    private var notNullClause: _BoolOr<_ConflictClause>?
    private var uniqueClause: _BoolOr<_ConflictClause>?
    private var check: _SQLExpression?
    private var defaults: _DefaultOption?
    private var collate: String?
    private var foreignKey: _ForeignKeyClause?

    private init(
        _ column: SQLColumn,
        primaryKey: _PrimaryKeyColumnConstraint?,
        type: _SQLType?,
        notNullClause: _BoolOr<_ConflictClause>?,
        uniqueClause: _BoolOr<_ConflictClause>?,
        check: _SQLExpression?,
        defaults: _DefaultOption?,
        collate: String?,
        foreignKey: _ForeignKeyClause?) {
        self.column = column
        self.primaryKey = primaryKey
        self.type = type
        self.notNullClause = notNullClause
        self.uniqueClause = uniqueClause
        self.check = check
        self.defaults = defaults
        self.collate = collate
        self.foreignKey = foreignKey
    }

    func build(_ db: Database) throws -> String {
        func build<T: _SQLStringConvertible>(constraint name: String, from c: _BoolOr<T>) -> String? {
            switch c {
            case .bool(let enabled) where enabled == true:
                return name
            case .other(let other):
                return [name, other.sql].joined(separator: " ")
            default: return nil
            }
        }
        var parts = [column.sql]
        if let type = type {
            parts.append(type.sql)
        }
        if let primaryKey = primaryKey {
            parts.append(primaryKey.sql)
        }
        if let notNullClause = notNullClause,
            constraint = build(constraint: "NOT NULL", from: notNullClause) {
            parts.append(constraint)
        }
        if let uniqueClause = uniqueClause,
            constraint = build(constraint: "UNIQUE", from: uniqueClause) {
            parts.append(constraint)
        }
        if let check = check {
            var arguments = StatementArguments()
            parts.append("CHECK")
            parts.append("(")
            try parts.append(check.sql(db, &arguments))
            parts.append(")")
        }
        // TODO: DEFAULT
        // TODO: COLLATE
        if let foreignKey = foreignKey {
            parts.append(foreignKey.sql)
        }
        return parts.joined(separator: " ")
    }

    @discardableResult public func primaryKey(autoincrement: Bool, onConflict: _ConflictResolution? = nil) -> _ColumnDef {
        var conflictClause: _ConflictClause? = nil
        if let onConflict = onConflict {
            conflictClause = _ConflictClause(resolution: onConflict)
        }
        primaryKey = _PrimaryKeyColumnConstraint(
            autoIncrement: autoincrement,
            order: nil,
            conflictClause: conflictClause)
        return self
    }

    @discardableResult public func primaryKey(order: _Order? = nil, onConflict: _ConflictResolution? = nil) -> _ColumnDef {
        var conflictClause: _ConflictClause? = nil
        if let onConflict = onConflict {
            conflictClause = _ConflictClause(resolution: onConflict)
        }
        primaryKey = _PrimaryKeyColumnConstraint(
            autoIncrement: false,
            order: order,
            conflictClause: conflictClause)
        return self
    }

    @discardableResult public func primaryKey(_ enabled: Bool) -> _ColumnDef {
        guard enabled == true else {
            primaryKey = nil
            return self
        }
        primaryKey = _PrimaryKeyColumnConstraint(
            autoIncrement: false,
            order: nil,
            conflictClause: nil)
        return self
    }

    @discardableResult public func notNull(_ enabled: Bool = true) -> _ColumnDef {
        notNullClause = _BoolOr.bool(enabled)
        return self
    }

    @discardableResult public func notNull(onConflict: _ConflictResolution) -> _ColumnDef {
        uniqueClause = _BoolOr.other(_ConflictClause(resolution: onConflict))
        return self
    }

    @discardableResult public func unique(_ enabled: Bool = true) -> _ColumnDef {
        uniqueClause = _BoolOr.bool(enabled)
        return self
    }

    @discardableResult public func unique(onConflict: _ConflictResolution) -> _ColumnDef {
        uniqueClause = _BoolOr.other(_ConflictClause(resolution: onConflict))
        return self
    }

    @discardableResult public func references(
        table: String,
        columns: SQLColumn...,
        onDelete: _DeleteUpdateAction? = nil,
        onUpdate: _DeleteUpdateAction? = nil,
        deferrable: Bool? = nil) -> _ColumnDef {
        foreignKey = _ForeignKeyClause(
            table: table,
            columns: columns,
            onDelete: onDelete,
            onUpdate: onUpdate,
            deferrable: deferrable)
        return self
    }

    // Doesn't work right now due to how expressions are generated (`?` character not allowed)
    @discardableResult public func check(_ predicate: _SQLExpressible) -> _ColumnDef {
        check = predicate.sqlExpression
        return self
    }

    @discardableResult public func check(sql: String, arguments: StatementArguments? = nil) -> _ColumnDef {
        return check(_SQLExpression.SQLLiteral(sql, arguments))
    }
}

extension Collection where Iterator.Element == _ColumnDef {
    func build(_ db: Database) throws -> String {
        return try map { try $0.build(db) }
            .joined(separator: ", ")
    }
}

extension Collection where Iterator.Element == _TableConstraint {
    func build(_ db: Database) throws -> String {
        return try map { try $0.build(db) }
            .joined(separator: ", ")
    }
}

protocol _TableConstraint: BuilderType {}

private struct _PrimaryKeyTableConstraint: _TableConstraint {
    var columns: [SQLColumn]
    var conflictClause: _ConflictClause?

    func build(_ db: Database) throws -> String {
        var parts = ["PRIMARY KEY"]
        guard columns.count > 0 else {
            throw DatabaseError(message: "At least one column required for constraint")
        }
        parts.append("(")
        parts.append(columns.map { $0.name }.joined(separator: ", "))
        parts.append(")")
        if let conflictClause = conflictClause {
            parts.append(conflictClause.sql)
        }
        return parts.joined(separator: " ")
    }
}

private struct _UniqueColumnsTableConstraint: _TableConstraint {
    var columns: [SQLColumn]
    var conflictClause: _ConflictClause?

    func build(_ db: Database) throws -> String {
        var parts = ["UNIQUE"]
        guard columns.count > 0 else {
            throw DatabaseError(message: "At least one column required for constraint")
        }
        parts.append("(")
        parts.append(columns.map { $0.name }.joined(separator: ", "))
        parts.append(")")
        if let conflictClause = conflictClause {
            parts.append(conflictClause.sql)
        }
        return parts.joined(separator: " ")
    }
}

private struct _CheckTableConstraint: _TableConstraint {
    var expression: _SQLExpression

    func build(_ db: Database) throws -> String {
        var parts = ["CHECK"]
        var arguments = StatementArguments()
        parts.append("CHECK")
        parts.append("(")
        try parts.append(expression.sql(db, &arguments))
        parts.append(")")
        return parts.joined(separator: " ")
    }
}

private struct _ForeignKeyTableConstraint: _TableConstraint {
    private var columns: [SQLColumn]
    private var foreignKey: _ForeignKeyClause

    func build(_ db: Database) throws -> String {
        var parts = ["FOREIGN KEY"]
        guard columns.count > 0 else {
            throw DatabaseError(message: "At least one column required for constraint")
        }
        parts.append("(")
        parts.append(columns.map { $0.name }.joined(separator: ", "))
        parts.append(")")
        parts.append(foreignKey.sql)
        return parts.joined(separator: " ")
    }
}

public struct _PrimaryKeyColumnConstraint: _SQLStringConvertible {
    var autoIncrement: Bool?
    var order: _Order?
    var conflictClause: _ConflictClause?

    public var sql: String {
        var parts = ["PRIMARY KEY"]
        if let order = order {
            parts.append(order.sql)
        }
        if let conflictClause = conflictClause {
            parts.append(conflictClause.sql)
        }
        if let autoIncrement = autoIncrement where autoIncrement == true {
            parts.append("AUTOINCREMENT")
        }
        return parts.joined(separator: " ")
    }
}

private struct _ForeignKeyClause: _SQLStringConvertible {
    var table: String
    var columns: [SQLColumn]
    var onDelete: _DeleteUpdateAction?
    var onUpdate: _DeleteUpdateAction?
    var deferrable: Bool?

    var sql: String {
        var parts = ["REFERENCES", table]
        if columns.count > 0 {
            parts.append("(")
            parts.append(columns.map { $0.name }.joined(separator: ", "))
            parts.append(")")
        }
        if let onDelete = onDelete {
            parts.append("ON DELETE")
            parts.append(onDelete.sql)
        }
        if let onUpdate = onUpdate {
            parts.append("ON UPDATE")
            parts.append(onUpdate.sql)
        }
        if let deferrable = deferrable where deferrable == true {
            parts.append("DEFERRABLE INITIALLY DEFERRED")
        }
        return parts.joined(separator: " ")
    }
}

struct _ConflictClause: _SQLStringConvertible {
    let resolution: _ConflictResolution

    var sql: String {
        return ["ON CONFLICT", resolution.sql].joined(separator: " ")
    }
}

public enum _DefaultOption {
    case number(Int)
    case literal(String)
    case expression(_SQLExpressible)
}

public enum _DeleteUpdateAction {
    case none
    case restrict
    case setNull
    case setDefault
    case cascade
}

public enum _ConflictResolution {
    case rollback
    case abort
    case fail
    case ignore
    case replace
}

public enum _Order {
    case asc
    case desc
}

public enum _BoolOr<T> {
    case bool(Bool)
    case other(T)
}

public enum _SQLType {
    case integer
    case text
    case double
    case blob
    case numeric
}

extension Database {
    public typealias CreateCallback = @noescape (table: _CreateTableStatement) -> Void

    @discardableResult public func create(
        table: String,
        temp: Bool = false,
        ifNotExists: Bool = false,
        withoutRowID: Bool = false,
        _ builder: CreateCallback) throws -> _CreateTableStatement {
        let stmt = _CreateTableStatement(
            temp: temp,
            ifNotExists: ifNotExists,
            name: table,
            columns: [],
            tableConstraints: [],
            withoutRowId: withoutRowID,
            select: nil)
        builder(table: stmt)
        try execute(stmt.build(self))
        return stmt
    }
}

extension _BoolOr: BooleanLiteralConvertible {
    public init(booleanLiteral value: Bool) {
        self = .bool(value)
    }
}

extension _DefaultOption: IntegerLiteralConvertible {
    public init(integerLiteral value: Int) {
        self = .number(value)
    }
}

extension SQLColumn: StringLiteralConvertible {
    public init(unicodeScalarLiteral value: String) {
        self = SQLColumn(value)
    }

    public init(extendedGraphemeClusterLiteral value: String) {
        self = SQLColumn(value)
    }

    public init(stringLiteral value: String) {
        self = SQLColumn(value)
    }
}

extension _DefaultOption: StringLiteralConvertible {
    public init(unicodeScalarLiteral value: String) {
        self = .literal(value)
    }

    public init(extendedGraphemeClusterLiteral value: String) {
        self = .literal(value)
    }

    public init(stringLiteral value: String) {
        self = .literal(value)
    }
}

extension _Order: _SQLStringConvertible {
    public var sql: String {
        switch self {
        case .asc: return "ASC"
        case .desc: return "DESC"
        }
    }
}

extension _ConflictResolution: _SQLStringConvertible {
    public var sql: String {
        switch self {
        case .rollback: return "ROLLBACK"
        case .abort: return "ABORT"
        case .fail: return "FAIL"
        case .ignore: return "IGNORE"
        case .replace: return "REPLACE"
        }
    }
}

extension _SQLType: _SQLStringConvertible {
    public var sql: String {
        switch self {
        case .integer: return "INTEGER"
        case .text: return "TEXT"
        case .double: return "DOUBLE"
        case .blob: return "BLOB"
        case .numeric: return "NUMERIC"
        }
    }
}

extension SQLColumn: _SQLStringConvertible {
    public var sql: String {
        return name
    }
}

extension _DeleteUpdateAction: _SQLStringConvertible {
    var sql: String {
        switch self {
        case .none: return "NO ACTION"
        case .restrict: return "RESTRICT"
        case .setNull: return "SET NULL"
        case .setDefault: return "SET DEFAULT"
        case .cascade: return "CASCADE"
        }
    }
}
