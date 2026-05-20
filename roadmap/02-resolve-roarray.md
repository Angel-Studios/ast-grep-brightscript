# 02 — Resolve the roArray field-type question

## Goal
Decide definitively whether `type="roArray"` is a valid SceneGraph field type on
the device, and reconcile the EBNF + checker accordingly.

## Context
`grammar/DEVICE_FACTS.md` marks **roArray INCONCLUSIVE**: a `<field type="roArray"/>`
with **no value** did not error, but a field type is only validated when a `value`
is present (exactly why the unquoted `stringarray` value DID error). The XSD lists
only `array`; `roArray` is currently removed from `grammar/scenegraph.ebnf`
`FieldType`.

## Steps
1. In `components/SpecShowcase.xml`, give the roArray field a value, e.g.
   `<field id="roArrayField" type="roArray" value='["x","y"]' />` (and/or set it
   from BrightScript in `SpecShowcase.brs`).
2. `npm run roku:deploy`; capture the console (the python capture helper or
   `bun run --cwd roku-listener listen`). Watch for a field-conversion error like
   the `stringarray` one.
3. **Verdict:**
   - **Errors** → roArray is invalid. Keep it out of `FieldType`. Move the
     DEVICE_FACTS entry to RESOLVED (invalid).
   - **Loads clean** → roArray is device-valid despite not being in the XSD.
     Restore `roArray` to `grammar/scenegraph.ebnf` `FieldType` with a
     `DEVICE-CONFIRMED` note, AND add a device-confirmed-extras allowlist to
     `grammar/check_scenegraph_xsd.py` so the XSD diff still passes. Update
     DEVICE_FACTS.

## Acceptance
The DEVICE_FACTS roArray entry is RESOLVED with the verdict; the EBNF, the XSD
checker, and the harness are mutually consistent and green.
