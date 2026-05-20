' test_collections.brs - exercises arrays and associative arrays.
'
' Array literals [], push/pop/append/count, dim (single + multi-dim), AA literals
' {} with identifier AND quoted-string keys, dot access, bracket access, iteration,
' and a multi-line literal spanning newlines inside the brackets.

sub test_collections_all(t as Object)
    ' --- Array literal -----------------------------------------------------
    t.spec("expr.array_literal", "ArrayLiteral", "array literal and ifArray methods (push/pop/append/shift)")
    arr = [1, 2, 3]
    t.assertEqual("col: array literal count", arr.count(), 3)

    t.spec("expr.index_suffix", "IndexSuffix", "[ ] index access on an array")
    t.assertEqual("col: array index access", arr[1], 2)

    ' push / pop.
    t.spec("expr.array_literal.methods", "ArrayLiteral", "ifArray push/pop/append/unshift/shift")
    arr.push(4)
    t.assertEqual("col: array push count", arr.count(), 4)
    last = arr.pop()
    t.assertEqual("col: array pop value", last, 4)

    ' append (concatenate another array).
    arr.append([10, 20])
    t.assertEqual("col: array append count", arr.count(), 5)

    ' unshift / shift.
    arr.unshift(0)
    t.assertEqual("col: array unshift head", arr[0], 0)
    arr.shift()
    t.assertEqual("col: array shift head", arr[0], 1)

    ' Multi-line array literal (newlines separate elements inside [ ]).
    t.spec("expr.array_literal.multiline", "ArrayLiteral", "multi-line array literal (newline element separators)")
    multi = [
        "a",
        "b",
        "c"
    ]
    t.assertEqual("col: multi-line array literal", multi.count(), 3)

    ' --- dim single-dimension array ----------------------------------------
    t.spec("stmt.dim.single", "DimStatement", "dim single-dimension array")
    dim grid[4]
    for i = 0 to 4
        grid[i] = i * i
    end for
    t.assertEqual("col: dim single-dim value", grid[3], 9)

    ' --- dim multi-dimension array -----------------------------------------
    t.spec("stmt.dim.multi", "DimStatement", "dim multi-dimension array")
    dim board[2, 2]
    board[0, 0] = "x"
    board[1, 1] = "o"
    t.assertEqual("col: dim multi-dim [0,0]", board[0, 0], "x")
    t.assertEqual("col: dim multi-dim [1,1]", board[1, 1], "o")

    ' --- Associative array literal: identifier + quoted-string keys ---------
    t.spec("expr.assoc_array_literal", "AssocArrayLiteral", "AA literal with identifier and quoted-string keys")
    aa = {
        name: "Roku",
        "display name": "Roku Player",
        qty: 3
    }
    t.assertEqual("col: AA identifier key (dot)", aa.name, "Roku")
    t.assertEqual("col: AA identifier key (bracket)", aa["qty"], 3)
    t.assertEqual("col: AA quoted-string key", aa["display name"], "Roku Player")

    ' Add / delete entries. (Use a key that is NOT also an roAssociativeArray
    ' method name, so dot-access after deletion returns invalid rather than a
    ' fallthrough method reference.)
    t.spec("expr.member_suffix", "MemberSuffix", ".member dot access / assignment / delete on an AA")
    aa.enabled = true
    t.assertTrue("col: AA dot assignment", aa.enabled)
    aa.delete("qty")
    t.assertInvalid("col: AA delete removes key", aa.qty)

    ' --- Iteration over AA keys --------------------------------------------
    t.spec("stmt.for_each.aa", "ForEachStatement", "for each over associative-array keys")
    sumVals = {}
    sumVals.a = 1
    sumVals.b = 2
    sumVals.c = 3
    keyTotal = 0
    for each key in sumVals
        keyTotal = keyTotal + sumVals[key]
    end for
    t.assertEqual("col: AA iteration sum", keyTotal, 6)

    ' --- Nested collections ------------------------------------------------
    t.spec("expr.assoc_array_literal.nested", "AssocArrayLiteral", "nested array/AA literals")
    nested = {
        list: [1, 2, [3, 4]],
        meta: { kind: "demo" }
    }
    t.assertEqual("col: nested array in AA", nested.list[2][1], 4)
    t.assertEqual("col: nested AA in AA", nested.meta.kind, "demo")

    ' --- Empty literals ----------------------------------------------------
    t.spec("expr.empty_literals", "ArrayLiteral", "empty array [] and empty AA {} literals")
    emptyArr = []
    emptyAA = {}
    t.assertEqual("col: empty array count", emptyArr.count(), 0)
    t.assertEqual("col: empty AA count", emptyAA.count(), 0)
end sub
