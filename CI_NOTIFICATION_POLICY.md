# CI Notification Policy

Goal: keep autonomous validation visible without generating repeated GitHub Actions failure emails.

- The headless suite still runs on `main` pushes.
- Test failures remain visible in logs and in the explicit `organism-cargo/godot-headless` commit status.
- The workflow job is allowed to fail at the workflow-conclusion layer (`continue-on-error: true`) so expected implementation-stage failures do not create repeated "Run failed" notifications.
- Never suppress or weaken a gameplay/contract test to make CI look green.
- One autonomous run should batch coherent work into at most one normal checkpoint push whenever practical.
