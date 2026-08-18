# AUTONOMY RULES

The implementation agent works from GitHub state, not chat memory. Every run must read `IMPLEMENTATION_START_HERE.md` and `IMPLEMENTATION_STATUS.md`, execute the exact next action, test the increment, save it, and update status. Never report completion before `IMPLEMENTATION COMPLETE = YES`.
