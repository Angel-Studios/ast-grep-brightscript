' main.brs - channel entry point.
'
' Standard roSGScreen boilerplate: create the screen, wire a message port,
' instantiate the root Scene, show it, and run the event loop until the screen
' is closed.
'
' SCOPING: the BrightScript construct test suite (TestSuite_Run / the test
' modules / the TestRunner framework) all live under pkg:/source/** which Roku
' compiles into the GLOBAL scope. SceneGraph component scripts (MainScene.brs)
' do NOT see those functions ("&h91 Function is not defined in component's
' namespace"; see grammar/DEVICE_FACTS.md). The Main scope, however, CAN see
' everything under pkg:/source/**, so we run the suite HERE - before showing the
' scene - and emit the ##SPEC## protocol from this scope. The results are then
' handed to MainScene via a field, which only renders them (no cross-scope call).

sub Main(args as Dynamic)
    ' Demonstrate reading the launch arguments (supports_input_launch=1 in the
    ' manifest). We never branch destructively on them - this is device-safe.
    if args <> invalid and Type(args) = "roAssociativeArray" then
        if args.DoesExist("contentId") then
            print "Launched with contentId: "; args.contentId
        end if
    end if

    ' --- Run the BrightScript spec suite from the Main (global) scope --------
    ' TestSuite_Run() runs every test module, prints the ##SPEC## protocol lines
    ' (run-start framing, one line per registered spec, run-end framing) to the
    ' debug console, and returns the results + summary for on-screen rendering.
    outcome = TestSuite_Run()
    print "Spec suite finished: PASS "; outcome.summary.passed; " / FAIL "; outcome.summary.failed; " (total "; outcome.summary.total; ")"

    ' --- Standard roSGScreen setup -----------------------------------------
    screen = CreateObject("roSGScreen")
    port = CreateObject("roMessagePort")
    screen.setMessagePort(port)

    ' Create the root scene declared by components/MainScene.xml.
    scene = screen.CreateScene("MainScene")
    screen.show()

    ' Hand the launch parameters AND the pre-computed test results to the scene
    ' via its interface. MainScene renders these without re-running the suite (it
    ' cannot - the suite functions are not in the component's namespace).
    ' Set the counts FIRST, then testResults LAST: setting testResults fires the
    ' scene's onTestResultsChanged observer, which renders using the counts, so
    ' the counts must already be in place.
    scene.setField("launchArgs", args)
    scene.setField("specResults", outcome.specs)

    ' --- Standard event loop ------------------------------------------------
    while true
        msg = wait(0, port)
        msgType = Type(msg)
        if msgType = "roSGScreenEvent" then
            if msg.isScreenClosed() then
                return
            end if
        end if
    end while
end sub
