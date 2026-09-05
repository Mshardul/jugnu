ObjC.import("Foundation");

const app = Application.currentApplication();
app.includeStandardAdditions = true;

const environment = $.NSProcessInfo.processInfo.environment;
const home = ObjC.unwrap(environment.objectForKey("HOME"));
const helperRoot = ObjC.unwrap(environment.objectForKey("JUGNU_HELPER_CLOCK"));
const stateDir = `${home}/.local/share/jugnu/state/nudges`;
const stateFile = `${stateDir}/nudges.yaml`;
const pendingDeleteFile = `${stateDir}/pending-delete`;
const clockFile = `${home}/.local/share/jugnu/state/clock/timers.json`;
const clockBinary = `${helperRoot}/bin/clock`;

const template = {
    emoji: "✨",
    title: "New nudge",
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
            throw new Error("invalid nudges yaml");
        }
        const target = section === "template" ? state.template : row;
        if (!target) {
            throw new Error("invalid nudges yaml");
        }
        target[property[2]] = parseScalar(property[3]);
    }

    if (!state.template.title || !Array.isArray(state.rows)) {
        throw new Error("invalid nudges yaml");
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
            `    emoji: ${yamlScalar(row.emoji)}`,
            `    title: ${yamlScalar(row.title)}`,
            `    message: ${yamlScalar(row.message)}`,
            `    interval_minutes: ${yamlScalar(row.interval_minutes)}`,
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

function timerFor(row, existing) {
    const intervalSeconds = Number(row.interval_minutes) * 60;
    return {
        id: `nudges:${row.id}`,
        kind: "interval",
        interval_seconds: intervalSeconds,
        enabled: true,
        paused: existing ? Boolean(existing.paused) : false,
        next_fire: existing
            ? existing.next_fire
            : new Date(Date.now() + intervalSeconds * 1000).toISOString(),
        group: "nudges",
        target: { addon: "nudges", command: "show-card" },
    };
}

function timerMatches(timer, row) {
    return (
        timer.kind === "interval"
        && timer.interval_seconds === Number(row.interval_minutes) * 60
        && timer.enabled === true
        && timer.group === "nudges"
        && timer.target
        && timer.target.addon === "nudges"
        && timer.target.command === "show-card"
    );
}

function upsert(row, existing) {
    clock({ op: "upsert", timer: timerFor(row, existing) });
}

function reconcile(state) {
    const timers = clock({ op: "list" }).timers || [];
    const byID = Object.fromEntries(timers.map((timer) => [timer.id, timer]));
    for (const row of state.rows) {
        if (row.enabled === false) {
            continue;
        }
        const existing = byID[`nudges:${row.id}`];
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
        subtitle: `${row.enabled === false ? "Disabled" : "Enabled"} · Every ${row.interval_minutes} min`,
        actions,
    }));
}

function selectedRowID(request) {
    const args = request.args || {};
    let rowID = args.rowId || args.itemId || args.timerId;
    if (typeof rowID === "string" && rowID.startsWith("nudges:")) {
        rowID = rowID.slice("nudges:".length);
    }
    return rowID;
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

function manage(state, timersByID, request) {
    const args = request.args || {};
    const rowID = selectedRowID(request);
    const action = actionFor(rowID);

    if (args.confirmed === true) {
        const deleteID = takePendingDelete();
        const index = state.rows.findIndex((candidate) => candidate.id === deleteID);
        if (index < 0) {
            return { ok: false, error: "Nudge not found." };
        }
        state.rows.splice(index, 1);
        writeState(state);
        clock({ op: "cancel", id: `nudges:${deleteID}` });
        return { ok: true, message: "Nudge deleted." };
    }

    if (rowID === "add") {
        return rowForm({ ...state.template, id: "", enabled: true }, "Add nudge");
    }

    if (action && action.name === "edit") {
        const row = state.rows.find((candidate) => candidate.id === action.rowID);
        return row
            ? rowForm(row, "Edit nudge", row.id)
            : { ok: false, error: "Nudge not found." };
    }

    if (action && action.name === "toggle") {
        const row = state.rows.find((candidate) => candidate.id === action.rowID);
        if (!row) {
            return { ok: false, error: "Nudge not found." };
        }
        row.enabled = row.enabled === false;
        writeState(state);
        if (row.enabled) {
            upsert(row, timersByID[`nudges:${row.id}`]);
        } else {
            clock({ op: "cancel", id: `nudges:${row.id}` });
        }
        return { ok: true, message: row.enabled ? "Nudge enabled." : "Nudge disabled." };
    }

    if (action && action.name === "delete") {
        const row = state.rows.find((candidate) => candidate.id === action.rowID);
        if (!row) {
            return { ok: false, error: "Nudge not found." };
        }
        writePendingDelete(row.id);
        return {
            ok: true,
            ui: {
                pattern: "confirm",
                title: `Delete ${row.title}?`,
                message: "This nudge and its timer will be removed.",
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
            ...validated.values,
            enabled: submitted.enabled !== false,
        };
        if (edit && index >= 0) {
            state.rows[index] = row;
        } else {
            state.rows.push(row);
        }
        writeState(state);
        if (row.enabled) {
            upsert(row, timersByID[`nudges:${id}`]);
        } else {
            clock({ op: "cancel", id: `nudges:${id}` });
        }
        return { ok: true, message: existingRow ? "Nudge saved." : "Nudge added." };
    }

    if (rowID) {
        const row = state.rows.find((candidate) => candidate.id === rowID);
        return row ? actionList(row) : { ok: false, error: "Nudge not found." };
    }

    return {
        ok: true,
        ui: {
            pattern: "list",
            title: "Nudges",
            placeholder: "Filter nudges",
            items: [
                ...rowItems(state, ["select"]),
                {
                    id: "add",
                    title: "➕ Add nudge",
                    subtitle: "Create a new nudge",
                    actions: ["select"],
                },
            ],
        },
    };
}

function advanced(state, request) {
    const args = request.args || {};
    if (args.confirmed === true) {
        state.template = { ...template };
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
        return { ok: false, error: "Nudge not found." };
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

function runCommand(request) {
    const state = readState();
    const timersByID = reconcile(state);

    if (request.command === "manage") {
        return manage(state, timersByID, request);
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
                title: "Nudge now",
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
        clock({ op: request.command, group: "nudges" });
        return {
            ok: true,
            message: request.command === "pause" ? "Nudges paused." : "Nudges resumed.",
        };
    }
    if (request.command === "restore-presets") {
        const known = new Set(state.rows.map((row) => row.id));
        const missing = presets.filter((preset) => !known.has(preset.id));
        state.rows.push(...missing.map((row) => ({ ...row })));
        writeState(state);
        for (const row of missing) {
            if (row.enabled !== false) {
                const existing = timersByID[`nudges:${row.id}`];
                if (!existing || !timerMatches(existing, row)) {
                    upsert(row, existing);
                }
            }
        }
        return { ok: true, message: "Nudge presets restored." };
    }
    if (request.command === "advanced") {
        return advanced(state, request);
    }
    return { ok: false, error: "Unknown nudge command." };
}

function run(argv) {
    try {
        return JSON.stringify(runCommand(JSON.parse(argv[0])));
    } catch (error) {
        return JSON.stringify({ ok: false, error: "Nudges could not complete that command." });
    }
}
