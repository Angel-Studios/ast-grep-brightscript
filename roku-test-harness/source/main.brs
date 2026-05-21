' main.brs - channel entry point.
'
' Drives ONE TestRunner across both layers of the coverage taxonomy
' (grammar/coverage.json) and emits a single ##SPEC## stream:
'
'   1. BrightScript specs (lex/decl/cc/stmt/expr) run in the Main (global) scope
'      via TestSuite_All() - these are pkg:/source/** functions, which Roku
'      compiles into the global scope.
'   2. SceneGraph specs run AFTER the scene is shown: test_scenegraph_all()
'      inspects the live root Scene and the hidden SpecShowcase child node and
'      folds its results into the SAME runner.
'
' SCOPING: SceneGraph component scripts do NOT see pkg:/source/** functions
' ("&h91 Function is not defined in component's namespace"; see
' grammar/DEVICE_FACTS.md). The Main scope CAN see everything under
' pkg:/source/**, so the whole suite is driven HERE; the scene only RENDERS the
' per-spec results it is handed via the 'specResults' field.

sub Main(args as Dynamic)
    ' Demonstrate reading the launch arguments (supports_input_launch=1 in the
    ' manifest). We never branch destructively on them - this is device-safe.
    if args <> invalid and Type(args) = "roAssociativeArray" then
        if args.DoesExist("contentId") then
            print "Launched with contentId: "; args.contentId
        end if
    end if

    ' --- 1. BrightScript spec modules (Main/global scope) -------------------
    runner = TestRunner_Create()
    runner.runAll(TestSuite_All())

    ' --- Standard roSGScreen setup -----------------------------------------
    screen = CreateObject("roSGScreen")
    port = CreateObject("roMessagePort")
    screen.setMessagePort(port)
    scene = screen.CreateScene("MainScene")
    screen.show()

    ' --- 2. SceneGraph specs against the live scene + showcase node ---------
    ' The hidden <SpecShowcase id="showcase"> child declares one field of every
    ' documented type plus alias/onChange/role/script/children forms; the root
    ' scene proves the extends="Scene" case. Both are inspected here and folded
    ' into the same runner so the ##SPEC## stream covers both layers.
    showcase = scene.findNode("showcase")
    test_scenegraph_all(runner, scene, showcase)

    ' --- 3. BrighterScript SceneGraph specs (render-phase) ------------------
    ' BrighterScript constructs that need a live roSGNode (the callfunc operator
    ' node@.method) run here, after the scene exists. Authored in
    ' source/tests/test_bs_sg.bs and transpiled to the global `test_bs_sg_all`.
    test_bs_sg_all(runner, showcase)

    ' --- Emit the unified ##SPEC## protocol --------------------------------
    ' run-start framing, one line per registered spec (BrightScript + SceneGraph),
    ' run-end framing - all from the Main scope, captured over telnet by
    ' roku-listener/.
    runner.emitSpecLines()

    summary = runner.summarize(runner.results)
    print "Spec suite finished: PASS "; summary.passed; " / FAIL "; summary.failed; " (total "; summary.total; ")"

    ' --- Hand launch args + per-spec results to the scene to render ---------
    scene.setField("launchArgs", args)
    scene.setField("specResults", runner.specs)

    ' --- Standard event loop ------------------------------------------------
    while true
        msg = wait(0, port)
        if Type(msg) = "roSGScreenEvent" then
            if msg.isScreenClosed() then
                return
            end if
        end if
    end while
end sub
