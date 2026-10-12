ObjC.import("Foundation");

const app = Application.currentApplication();
app.includeStandardAdditions = true;

const environment = $.NSProcessInfo.processInfo.environment;
const home = ObjC.unwrap(environment.objectForKey("HOME"));
const helperRoot = ObjC.unwrap(environment.objectForKey("JUGNU_HELPER_CLOCK"));
const stateDir = `${home}/.local/share/jugnu/state/intervals`;
const stateFile = `${stateDir}/intervals.yaml`;
const GROUP = "intervals";
const ADDON_ID = "jugnu.intervals";
const pendingDeleteFile = `${stateDir}/pending-delete`;
const clockFile = `${home}/.local/share/jugnu/state/clock/timers.json`;
const clockBinary = `${helperRoot}/bin/clock`;

const template = {
    emoji: "✨",
    title: "New interval",
    message: "A small reminder.",
    interval_minutes: 30,
    accent: null,
};

const presets = [
    {
        id: "eye-rest",
        emoji: "👀",
        title: "Eyes",
        message: "Glow somewhere farther away for a bit.",
        interval_minutes: 20,
        accent: null,
        enabled: true,
    },
    {
        id: "water",
        emoji: "💧",
        title: "Water",
        message: "Your cells called. They’re thirsty.",
        interval_minutes: 45,
        accent: null,
        enabled: true,
    },
    {
        id: "stretch",
        emoji: "🧘",
        title: "Stretch",
        message: "Uncurl. The chair will survive.",
        interval_minutes: 60,
        accent: null,
        enabled: true,
    },
    {
        id: "pomodoro",
        kind: "phases",
        emoji: "🍅",
        title: "Pomodoro",
        message: "Focus. The glow can wait.",
        interval_minutes: 25,
        break_minutes: 5,
        break_message: "Look up. The chair will keep your shape.",
        phase: "work",
        accent: null,
        enabled: false,
    },
];

function shellQuote(value) {
    return `'${String(value).replace(/'/g, "'\\''")}'`;
}

function clock(request) {
    request.file = clockFile;
    const payload = JSON.stringify(request);
    const output = app.doShellScript(
        `/usr/bin/printf '%s\\n' ${shellQuote(payload)} | ${shellQuote(clockBinary)}`,
    );
    const response = JSON.parse(output);
    if (!response.ok) {
        throw new Error("clock request failed");
    }
    return response;
}

function parseScalar(source) {
    const value = source.trim();
    if (value === "null") {
        return null;
    }
    if (value === "true") {
        return true;
    }
    if (value === "false") {
        return false;
    }
    if (/^-?\d+$/.test(value)) {
        return Number(value);
    }
    if (value.startsWith('"')) {
        return JSON.parse(value);
    }
    return value;
}

function parseState(source) {
    const state = { template: {}, rows: [] };
    let section = null;
    let row = null;

    for (const line of source.split(/\r?\n/)) {
        if (line === "" || line.trimStart().startsWith("#")) {
            continue;
        }
        if (line === "template:") {
            section = "template";
            row = null;
            continue;
        }
        if (line === "rows:") {
            section = "rows";
            row = null;
            continue;
        }

        const rowStart = line.match(/^  - id:\s*(.+)$/);
        if (section === "rows" && rowStart) {
            row = { id: parseScalar(rowStart[1]) };
            state.rows.push(row);
            continue;
        }

        const property = line.match(/^(  |    )([a-z_]+):\s*(.*)$/);
        if (!property) {
            throw new Error("invalid intervals yaml");
        }
        const target = section === "template" ? state.template : row;
        if (!target) {
            throw new Error("invalid intervals yaml");
        }
        target[property[2]] = parseScalar(property[3]);
    }

    if (!state.template.title || !Array.isArray(state.rows)) {
        throw new Error("invalid intervals yaml");
    }
    return state;
}

function yamlScalar(value) {
    if (value === null || value === undefined || typeof value === "boolean") {
        return String(value ?? "null");
    }
    if (typeof value === "number") {
        return String(value);
    }
    return JSON.stringify(String(value));
}

function serializeState(state) {
    const lines = [
        "template:",
        `  emoji: ${yamlScalar(state.template.emoji)}`,
        `  title: ${yamlScalar(state.template.title)}`,
        `  message: ${yamlScalar(state.template.message)}`,
        `  interval_minutes: ${yamlScalar(state.template.interval_minutes)}`,
        `  accent: ${yamlScalar(state.template.accent)}`,
        "rows:",
    ];
    for (const row of state.rows) {
        lines.push(
            `  - id: ${yamlScalar(row.id)}`,
            `    kind: ${yamlScalar(rowKind(row))}`,
            `    emoji: ${yamlScalar(row.emoji)}`,
            `    title: ${yamlScalar(row.title)}`,
            `    message: ${yamlScalar(row.message)}`,
            `    interval_minutes: ${yamlScalar(row.interval_minutes)}`,
        );
        if (rowKind(row) === "phases") {
            lines.push(
                `    break_minutes: ${yamlScalar(row.break_minutes)}`,
                `    break_message: ${yamlScalar(row.break_message)}`,
                `    phase: ${yamlScalar(row.phase === "break" ? "break" : "work")}`,
            );
        }
        lines.push(
            `    accent: ${yamlScalar(row.accent)}`,
            `    enabled: ${yamlScalar(row.enabled !== false)}`,
        );
    }
    return `${lines.join("\n")}\n`;
}

function readState() {
    const manager = $.NSFileManager.defaultManager;
    if (!manager.fileExistsAtPath(stateFile)) {
        const state = {
            template: { ...template },
            rows: presets.map((row) => ({ ...row })),
        };
        writeState(state);
        return state;
    }
    const contents = $.NSString.stringWithContentsOfFileEncodingError(
        stateFile,
        $.NSUTF8StringEncoding,
        null,
    );
    return parseState(ObjC.unwrap(contents));
}

function writeState(state) {
    $.NSFileManager.defaultManager.createDirectoryAtPathWithIntermediateDirectoriesAttributesError(
        stateDir,
        true,
        $(),
        null,
    );
    const written = $(serializeState(state)).writeToFileAtomicallyEncodingError(
        stateFile,
        true,
        $.NSUTF8StringEncoding,
        null,
    );
    if (!written) {
        throw new Error("state write failed");
    }
}

function rowKind(row) {
    return row.kind === "phases" ? "phases" : "interval";
}

function phaseName(row) {
    return row.phase === "break" ? "break" : "work";
}

function phaseMinutes(row, phase) {
    if (phase === "break") {
        return Number(row.break_minutes);
    }
    return Number(row.interval_minutes);
}

function isoStamp(date) {
    return date.toISOString().replace(/\.\d{3}Z$/, "Z");
}

function timerIDFor(row, phase) {
    if (rowKind(row) === "phases") {
        return `${GROUP}:${row.id}:${phase || phaseName(row)}`;
    }
    return `${GROUP}:${row.id}`;
}

function timerFor(row, existing) {
    if (rowKind(row) === "phases") {
        const phase = phaseName(row);
        const seconds = phaseMinutes(row, phase) * 60;
        const fire = existing && existing.next_fire
            ? existing.next_fire
            : isoStamp(new Date(Date.now() + seconds * 1000));
        return {
            id: timerIDFor(row, phase),
            kind: "one-shot",
            fire_at: fire,
            enabled: true,
            paused: existing ? Boolean(existing.paused) : false,
            next_fire: fire,
            group: GROUP,
            target: { addon: ADDON_ID, command: "phase-chime" },
        };
    }
    const intervalSeconds = Number(row.interval_minutes) * 60;
    return {
        id: timerIDFor(row),
        kind: "interval",
        interval_seconds: intervalSeconds,
        enabled: true,
        paused: existing ? Boolean(existing.paused) : false,
        next_fire: existing
            ? existing.next_fire
            : isoStamp(new Date(Date.now() + intervalSeconds * 1000)),
        group: GROUP,
        target: { addon: ADDON_ID, command: "show-card" },
    };
}

function timerMatches(timer, row) {
    if (rowKind(row) === "phases") {
        return (
            timer.kind === "one-shot"
            && timer.id === timerIDFor(row)
            && timer.enabled === true
            && timer.group === GROUP
            && timer.target
            && timer.target.addon === ADDON_ID
            && timer.target.command === "phase-chime"
        );
    }
    return (
        timer.kind === "interval"
        && timer.interval_seconds === Number(row.interval_minutes) * 60
        && timer.enabled === true
        && timer.group === GROUP
        && timer.target
        && timer.target.addon === ADDON_ID
        && timer.target.command === "show-card"
    );
}

function upsert(row, existing) {
    clock({ op: "upsert", timer: timerFor(row, existing) });
}

function cancelRow(row) {
    if (rowKind(row) === "phases") {
        clock({ op: "cancel", id: `${GROUP}:${row.id}:work` });
        clock({ op: "cancel", id: `${GROUP}:${row.id}:break` });
        return;
    }
    clock({ op: "cancel", id: timerIDFor(row) });
}

function reconcile(state) {
    const timers = clock({ op: "list" }).timers || [];
    const byID = Object.fromEntries(timers.map((timer) => [timer.id, timer]));
    for (const row of state.rows) {
        if (row.enabled === false) {
            continue;
        }
        const existing = byID[timerIDFor(row)];
        if (!existing || !timerMatches(existing, row)) {
            upsert(row, existing);
        }
    }
    return byID;
}

function rowItems(state, actions) {
    return state.rows.map((row) => ({
        id: row.id,
        title: `${row.emoji} ${row.title}`,
        subtitle: rowSubtitle(row),
        actions,
    }));
}

function selectedRowID(request) {
    const args = request.args || {};
    let rowID = args.rowId || args.itemId || args.timerId;
    if (typeof rowID === "string" && rowID.startsWith(`${GROUP}:`)) {
        rowID = rowID.slice(GROUP.length + 1);
        const phaseAt = rowID.lastIndexOf(":");
        if (phaseAt > 0) {
            const phase = rowID.slice(phaseAt + 1);
            if (phase === "work" || phase === "break") {
                rowID = rowID.slice(0, phaseAt);
            }
        }
    }
    return rowID;
}

function rowSubtitle(row) {
    const stateLabel = row.enabled === false ? "Disabled" : "Enabled";
    if (rowKind(row) === "phases") {
        return `${stateLabel} · Focus ${row.interval_minutes}m / break ${row.break_minutes}m`;
    }
    return `${stateLabel} · Every ${row.interval_minutes} min`;
}

function formFields(values, includesID, includesEnabled, messageID) {
    const fields = [];
    if (includesID) {
        fields.push({ id: "id", label: "ID", kind: "text", value: values.id || "" });
    }
    fields.push(
        { id: "emoji", label: "Emoji", kind: "text", value: values.emoji || "" },
        { id: "title", label: "Title", kind: "text", value: values.title || "" },
        { id: messageID || "message", label: "Message", kind: "text", value: values.message || "" },
        {
            id: "interval_minutes",
            label: "Interval (minutes)",
            kind: "text",
            value: Number(values.interval_minutes),
        },
        { id: "accent", label: "Accent", kind: "text", value: values.accent || "" },
    );
    if (rowKind(values) === "phases") {
        fields.push(
            {
                id: "break_minutes",
                label: "Break (minutes)",
                kind: "text",
                value: Number(values.break_minutes),
            },
            {
                id: "break_message",
                label: "Break message",
                kind: "text",
                value: values.break_message || "",
            },
        );
    }
    if (includesEnabled) {
        fields.push({
            id: "enabled",
            label: "Enabled",
            kind: "toggle",
            value: values.enabled !== false,
        });
    }
    return fields;
}

function rowForm(values, title, identity) {
    return {
        ok: true,
        ui: {
            pattern: "form",
            title,
            fields: formFields(
                values,
                !identity,
                true,
                identity ? `edit:${encodeURIComponent(identity)}:message` : "message",
            ),
        },
    };
}

function actionFor(itemID) {
    const separator = typeof itemID === "string" ? itemID.indexOf(":") : -1;
    if (separator < 0) {
        return null;
    }
    return {
        name: itemID.slice(0, separator),
        rowID: decodeURIComponent(itemID.slice(separator + 1)),
    };
}

function editSubmission(args) {
    for (const key of Object.keys(args)) {
        const match = key.match(/^edit:(.*):message$/);
        if (match) {
            return {
                rowID: decodeURIComponent(match[1]),
                args: { ...args, message: args[key] },
            };
        }
    }
    return null;
}

function writePendingDelete(rowID) {
    $.NSFileManager.defaultManager.createDirectoryAtPathWithIntermediateDirectoriesAttributesError(
        stateDir,
        true,
        $(),
        null,
    );
    const written = $(rowID).writeToFileAtomicallyEncodingError(
        pendingDeleteFile,
        true,
        $.NSUTF8StringEncoding,
        null,
    );
    if (!written) {
        throw new Error("pending delete write failed");
    }
}

function takePendingDelete() {
    const manager = $.NSFileManager.defaultManager;
    if (!manager.fileExistsAtPath(pendingDeleteFile)) {
        return null;
    }
    const contents = $.NSString.stringWithContentsOfFileEncodingError(
        pendingDeleteFile,
        $.NSUTF8StringEncoding,
        null,
    );
    manager.removeItemAtPathError(pendingDeleteFile, null);
    return ObjC.unwrap(contents);
}

function actionList(row) {
    const encodedID = encodeURIComponent(row.id);
    return {
        ok: true,
        ui: {
            pattern: "list",
            title: `${row.emoji} ${row.title}`,
            items: [
                { id: `toggle:${encodedID}`, title: "🔁 Toggle", actions: ["select"] },
                { id: `edit:${encodedID}`, title: "✏️ Edit", actions: ["select"] },
                { id: `delete:${encodedID}`, title: "🗑️ Delete", actions: ["select"] },
            ],
        },
    };
}

function validatedValues(args) {
    const message = String(args.message || "").trim();
    if (!message) {
        return { error: "Message is required." };
    }
    const interval = Number(args.interval_minutes);
    if (!Number.isFinite(interval) || interval <= 0) {
        return { error: "Interval must be greater than zero." };
    }
    return {
        values: {
            emoji: String(args.emoji || "").trim(),
            title: String(args.title || "").trim(),
            message,
            interval_minutes: interval,
            accent: String(args.accent || "").trim() || null,
        },
    };
}

function manage(state, timersByID, request, config) {
    const args = request.args || {};
    const rowID = selectedRowID(request);
    const action = actionFor(rowID);

    if (args.confirmed === true) {
        const deleteID = takePendingDelete();
        const index = state.rows.findIndex((candidate) => candidate.id === deleteID);
        if (index < 0) {
            return { ok: false, error: "Interval not found." };
        }
        const removed = state.rows[index];
        state.rows.splice(index, 1);
        writeState(state);
        cancelRow(removed);
        return { ok: true, message: "Interval deleted." };
    }

    if (rowID === "add") {
        return rowForm({
            ...state.template,
            interval_minutes: config.default_interval_minutes,
            id: "",
            enabled: true,
        }, "Add interval");
    }

    if (rowID === "nudge-now") {
        return {
            ok: true,
            ui: {
                pattern: "list",
                title: "Show interval now",
                placeholder: "Choose a nudge",
                items: rowItems(
                    { rows: state.rows.filter((row) => row.enabled !== false) },
                    ["select"],
                ).map((item) => ({ ...item, id: `now:${item.id}` })),
            },
        };
    }

    if (typeof rowID === "string" && rowID.indexOf("now:") === 0) {
        return cardFor(state, rowID.slice(4));
    }

    if (action && action.name === "edit") {
        const row = state.rows.find((candidate) => candidate.id === action.rowID);
        return row
            ? rowForm(row, "Edit nudge", row.id)
            : { ok: false, error: "Interval not found." };
    }

    if (action && action.name === "toggle") {
        const row = state.rows.find((candidate) => candidate.id === action.rowID);
        if (!row) {
            return { ok: false, error: "Interval not found." };
        }
        row.enabled = row.enabled === false;
        writeState(state);
        if (row.enabled) {
            upsert(row, timersByID[timerIDFor(row)]);
        } else {
            cancelRow(row);
        }
        return { ok: true, message: row.enabled ? "Interval enabled." : "Interval disabled." };
    }

    if (action && action.name === "delete") {
        const row = state.rows.find((candidate) => candidate.id === action.rowID);
        if (!row) {
            return { ok: false, error: "Interval not found." };
        }
        writePendingDelete(row.id);
        return {
            ok: true,
            ui: {
                pattern: "confirm",
                title: `Delete ${row.title}?`,
                message: "This interval and its timer will be removed.",
                confirmLabel: "Delete",
                cancelLabel: "Cancel",
            },
        };
    }

    const edit = editSubmission(args);
    if (edit || Object.prototype.hasOwnProperty.call(args, "message")) {
        const id = edit ? edit.rowID : String(args.id || "").trim();
        if (!id) {
            return { ok: false, error: "ID is required." };
        }
        const submitted = edit ? edit.args : args;
        const validated = validatedValues(submitted);
        if (validated.error) {
            return { ok: false, error: validated.error };
        }
        const index = state.rows.findIndex((candidate) => candidate.id === id);
        const existingRow = index >= 0 ? state.rows[index] : null;
        if (!edit && existingRow) {
            return { ok: false, error: "ID already exists." };
        }
        const row = {
            id,
            kind: existingRow ? rowKind(existingRow) : "interval",
            ...validated.values,
            enabled: submitted.enabled !== false,
        };
        if (row.kind === "phases") {
            const breakMinutes = Number(submitted.break_minutes);
            const breakMessage = String(submitted.break_message || "").trim();
            if (!breakMessage) {
                return { ok: false, error: "Break message is required." };
            }
            if (!Number.isFinite(breakMinutes) || breakMinutes <= 0) {
                return { ok: false, error: "Break must be greater than zero." };
            }
            row.break_minutes = breakMinutes;
            row.break_message = breakMessage;
            row.phase = existingRow && existingRow.phase === "break" ? "break" : "work";
        }
        if (edit && index >= 0) {
            state.rows[index] = row;
        } else {
            state.rows.push(row);
        }
        writeState(state);
        if (row.enabled) {
            upsert(row, timersByID[timerIDFor(row)]);
        } else {
            cancelRow(row);
        }
        return { ok: true, message: existingRow ? "Interval saved." : "Interval added." };
    }

    if (rowID) {
        const row = state.rows.find((candidate) => candidate.id === rowID);
        return row ? actionList(row) : { ok: false, error: "Interval not found." };
    }

    const items = [
        ...rowItems(state, ["select"]),
        {
            id: "add",
            title: "➕ Add interval",
            subtitle: "Create a new interval",
            actions: ["select"],
        },
    ];
    if (config.show_nudge_now_in_manage) {
        items.push({
            id: "nudge-now",
            title: "⚡ Show interval now",
            subtitle: "Show a timer card immediately",
            actions: ["select"],
        });
    }

    return {
        ok: true,
        ui: {
            pattern: "list",
            title: "Intervals",
            placeholder: "Filter intervals",
            items,
        },
    };
}

function advanced(state, request, config) {
    const args = request.args || {};
    if (args.confirmed === true) {
        state.template = {
            ...template,
            interval_minutes: config.default_interval_minutes,
        };
        writeState(state);
        return { ok: true, message: "Template reset." };
    }
    if (args.reset === true) {
        return {
            ok: true,
            ui: {
                pattern: "confirm",
                title: "Reset template?",
                message: "Restore the factory new-nudge template.",
                confirmLabel: "Reset",
                cancelLabel: "Cancel",
            },
        };
    }
    if (Object.prototype.hasOwnProperty.call(args, "message")) {
        const validated = validatedValues(args);
        if (validated.error) {
            return { ok: false, error: validated.error };
        }
        state.template = validated.values;
        writeState(state);
        return { ok: true, message: "Template saved." };
    }
    return {
        ok: true,
        ui: {
            pattern: "form",
            title: "New nudge template",
            fields: [
                ...formFields(state.template, false, false),
                {
                    id: "reset",
                    label: "Reset to factory template",
                    kind: "toggle",
                    value: false,
                },
            ],
        },
    };
}

function cardFor(state, rowID) {
    const row = state.rows.find((candidate) => candidate.id === rowID);
    if (!row) {
        return { ok: false, error: "Interval not found." };
    }
    const ui = {
        pattern: "card",
        title: row.title,
        emoji: row.emoji,
        message: row.message,
    };
    if (row.accent) {
        ui.accent = row.accent;
    }
    return { ok: true, ui };
}

function pomodoroRow(state) {
    return state.rows.find((row) => row.id === "pomodoro" && rowKind(row) === "phases");
}

function startPhase(state, phase) {
    const row = pomodoroRow(state);
    if (!row) {
        return { ok: false, error: "Pomodoro preset is missing." };
    }
    row.enabled = true;
    row.phase = phase;
    writeState(state);
    cancelRow(row);
    upsert(row, null);
    return { ok: true, message: `${phase} started (${phaseMinutes(row, phase)}m)` };
}

function resetPomodoro(state) {
    const row = pomodoroRow(state);
    if (row) {
        row.enabled = false;
        row.phase = "work";
        writeState(state);
        cancelRow(row);
    }
    return { ok: true, message: "pomodoro reset" };
}

function pomodoroStatus(state) {
    const row = pomodoroRow(state);
    if (!row || row.enabled === false) {
        return { ok: true, message: "idle" };
    }
    const phase = phaseName(row);
    const timers = clock({ op: "list" }).timers || [];
    const timer = timers.find((candidate) => candidate.id === timerIDFor(row, phase));
    if (!timer || !timer.next_fire) {
        return { ok: true, message: "idle" };
    }
    const end = Date.parse(timer.next_fire);
    if (!Number.isFinite(end)) {
        return { ok: true, message: "idle" };
    }
    const remaining = Math.max(0, Math.floor((end - Date.now()) / 1000));
    if (remaining <= 0) {
        return { ok: true, message: "idle" };
    }
    const mins = Math.floor(remaining / 60);
    const secs = remaining % 60;
    return { ok: true, message: `${phase}: ${mins}m ${secs}s remaining` };
}

function phaseFromTimerID(raw) {
    if (typeof raw !== "string" || raw.indexOf(`${GROUP}:`) !== 0) {
        return null;
    }
    const rest = raw.slice(GROUP.length + 1);
    const phaseAt = rest.lastIndexOf(":");
    if (phaseAt < 0) {
        return null;
    }
    const phase = rest.slice(phaseAt + 1);
    return phase === "work" || phase === "break" ? phase : null;
}

function phaseChime(state, request) {
    const args = request.args || {};
    const timerID = args.timerId || args.rowId || "";
    const rowID = selectedRowID(request);
    const row = state.rows.find((candidate) => candidate.id === rowID);
    if (!row || rowKind(row) !== "phases") {
        return { ok: false, error: "Interval not found." };
    }
    const finished = phaseFromTimerID(timerID) || phaseName(row);
    const message = finished === "break" ? row.break_message : row.message;
    if (row.enabled !== false) {
        row.phase = finished === "work" ? "break" : "work";
        writeState(state);
        upsert(row, null);
    }
    const ui = {
        pattern: "card",
        title: row.title,
        emoji: row.emoji,
        message,
    };
    if (row.accent) {
        ui.accent = row.accent;
    }
    return { ok: true, ui };
}

function readConfig(request) {
    const config = request.config || {};
    let interval = 30;
    if (typeof config.default_interval_minutes === "number") {
        interval = config.default_interval_minutes;
    }
    let showNudgeNow = true;
    if (typeof config.show_nudge_now_in_manage === "boolean") {
        showNudgeNow = config.show_nudge_now_in_manage;
    }
    return {
        default_interval_minutes: interval,
        show_nudge_now_in_manage: showNudgeNow,
    };
}

function runCommand(request) {
    const config = readConfig(request);
    const state = readState();
    const timersByID = reconcile(state);

    if (request.command === "manage") {
        return manage(state, timersByID, request, config);
    }
    if (request.command === "nudge-now") {
        const rowID = selectedRowID(request);
        if (rowID) {
            return cardFor(state, rowID);
        }
        return {
            ok: true,
            ui: {
                pattern: "list",
                title: "Show interval now",
                placeholder: "Choose a nudge",
                items: rowItems(
                    { rows: state.rows.filter((row) => row.enabled !== false) },
                    ["select"],
                ),
            },
        };
    }
    if (request.command === "show-card") {
        return cardFor(state, selectedRowID(request));
    }
    if (request.command === "pause" || request.command === "resume") {
        clock({ op: request.command, group: GROUP });
        return {
            ok: true,
            message: request.command === "pause" ? "Intervals paused." : "Intervals resumed.",
        };
    }
    if (request.command === "restore-presets") {
        const known = new Set(state.rows.map((row) => row.id));
        const missing = presets.filter((preset) => !known.has(preset.id));
        state.rows.push(...missing.map((row) => ({ ...row })));
        writeState(state);
        for (const row of missing) {
            if (row.enabled !== false) {
                const existing = timersByID[timerIDFor(row)];
                if (!existing || !timerMatches(existing, row)) {
                    upsert(row, existing);
                }
            }
        }
        return { ok: true, message: "Interval presets restored." };
    }
    if (request.command === "advanced") {
        return advanced(state, request, config);
    }
    if (request.command === "start-focus") {
        return startPhase(state, "work");
    }
    if (request.command === "start-break") {
        return startPhase(state, "break");
    }
    if (request.command === "pomodoro-status") {
        return pomodoroStatus(state);
    }
    if (request.command === "reset-pomodoro") {
        return resetPomodoro(state);
    }
    if (request.command === "phase-chime") {
        return phaseChime(state, request);
    }
    return { ok: false, error: "Unknown interval command." };
}

function run(argv) {
    try {
        return JSON.stringify(runCommand(JSON.parse(argv[0])));
    } catch (error) {
        return JSON.stringify({ ok: false, error: "Intervals could not complete that command." });
    }
}
