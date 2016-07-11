import GRDB

// Open an in-memory database that logs all SQL statements
var configuration = Configuration()
configuration.trace = { print($0) }
let dbq = DatabaseQueue(configuration: configuration)

print("foo")

try dbq.inDatabase { db in
    try db.create(table: "foo") { table in
        table.column("id", type: .integer)
    }
}

//SQL.create(table: "foo", ifNotExists: true)
//    .column(
//        name: "id",
//        primaryKey: SQL.primaryKey(autoIncrement: true),
//        affinity: .integer,
//        notNull: true)
//
//SQL.create(table: "foo", ifNotExists: true)
//    .column(
//        name: "id",
//        primaryKey: SQL.primaryKey(
//            autoIncrement: true,
//            order: .desc,
//            onConflict: .abort),
//        affinity: .integer,
//        notNull: true)
//
//SQL.create(table: "foo", ifNotExists: true)
//    .column(
//        name: "id",
//        primaryKey: SQL.primaryKey(onConflict: .abort),
//        affinity: .integer,
//        notNull: true)
//
//SQL.create(table: "foo", ifNotExists: true)
//    .column(
//        name: "bar_id",
//        affinity: .integer,
//        references: SQL.foreignKey(
//            table: "bar",
//            columns: "id"))
//
//SQL.create(table: "foo", ifNotExists: true)
//    .column(
//        name: "bar_id",
//        affinity: .integer,
//        references: SQL.foreignKey(
//            table: "bar",
//            columns: "id",
//            onDelete: .cascade,
//            onUpdate: .cascade,
//            deferrable: true))
//
//let fooId: SQLColumn = "foo_id"
//let bazId: SQLColumn = "baz_id"
//let a: SQLColumn = "a"
//let b: SQLColumn = "b"
//let c: SQLColumn = "c"
//
//SQL.create(table: "bar", ifNotExists: true)
//    .column(name: fooId, affinity: .integer)
//    .column(name: bazId, affinity: .integer)
//    .column(name: a, affinity: .integer)
//    .column(name: b, affinity: .integer)
//    .column(name: c, affinity: .integer)
//    .unique(columns: fooId, bazId, onConflict: .rollback)
//    .primaryKey(columns: a, b, c, onConflict: .rollback)
//    .foreignKey(
//        columns: fooId,
//        onConflict: .rollback,
//        references: SQL.foreignKey(
//            table: "foo",
//            columns: "id"))
//    .foreignKey(
//        columns: bazId,
//        onConflict: .rollback,
//        references: SQL.foreignKey(
//            table: "baz",
//            columns: "id"))
//    .check(a != b)
//    .check(b != c)
//
//SQL.create(table: "foo", ifNotExists: true)
//    .column(name: "id", affinity: .integer)
//    .column(name: "a", default: 1)
