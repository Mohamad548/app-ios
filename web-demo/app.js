/**
 * SIM800 Control — Web DEMO
 * UI از SmartRelay Asset Kit + منطق فیک SMS (بدون ارسال واقعی)
 */
(function () {
  "use strict";

  const KEY = "sim800-web-demo-v2";
  const THEME = "dark";
  const LAYER = `kit/fans/layers/${THEME}`;
  const ARC = "kit/fans/layers/progress-arc.svg";
  const POWER = "kit/icons/svg/power.svg";
  const FAN_THUMB = `kit/fans/svg/${THEME}/fan-off.svg`;

  const DEFAULTS = {
    phone: "",
    pin: "0000",
    names: ["فەن ١", "فەن ٢", "فەن ٣", "فەن ٤"],
    relays: [false, false, false, false],
    silent: true,
    log: [],
    seenSplash: false,
    lastReplyAt: null,
  };

  /** @type {typeof DEFAULTS} */
  let state = load();
  let logFilter = "all";
  let busyAll = false;
  /** @type {Record<number, string>} */
  const ui = { 0: "off", 1: "off", 2: "off", 3: "off" };

  const $ = (s, r = document) => r.querySelector(s);
  const $$ = (s, r = document) => [...r.querySelectorAll(s)];

  function load() {
    try {
      const raw = localStorage.getItem(KEY);
      if (!raw) return { ...DEFAULTS, names: DEFAULTS.names.slice(), relays: [false, false, false, false], log: [] };
      const p = JSON.parse(raw);
      return {
        ...DEFAULTS,
        ...p,
        names: Array.isArray(p.names) && p.names.length === 4 ? p.names : DEFAULTS.names.slice(),
        relays: Array.isArray(p.relays) && p.relays.length === 4 ? p.relays.map(Boolean) : [false, false, false, false],
        log: Array.isArray(p.log) ? p.log.slice(0, 100) : [],
      };
    } catch {
      return { ...DEFAULTS, names: DEFAULTS.names.slice(), relays: [false, false, false, false], log: [] };
    }
  }

  function save() {
    localStorage.setItem(KEY, JSON.stringify(state));
  }

  function digits(v) {
    return String(v || "")
      .replace(/[۰-۹]/g, (d) => String("۰۱۲۳۴۵۶۷۸۹".indexOf(d)))
      .replace(/[٠-٩]/g, (d) => String("٠١٢٣٤٥٦٧٨٩".indexOf(d)))
      .replace(/[\s\-()]/g, "")
      .trim();
  }

  function esc(s) {
    return String(s)
      .replace(/&/g, "&amp;")
      .replace(/</g, "&lt;")
      .replace(/>/g, "&gt;")
      .replace(/"/g, "&quot;");
  }

  function show(id) {
    $$(".view").forEach((v) => v.classList.remove("active"));
    const el = $(`#view-${id}`);
    if (el) el.classList.add("active");
  }

  function toast(msg, error = false) {
    const el = $("#toast");
    el.textContent = msg;
    el.classList.toggle("error", error);
    el.hidden = false;
    clearTimeout(toast._t);
    toast._t = setTimeout(() => {
      el.hidden = true;
    }, 2600);
  }

  function sheet(text) {
    const wrap = $("#sheet");
    const bar = $("#sheet-bar");
    $("#sheet-text").textContent = text;
    wrap.hidden = false;
    bar.classList.remove("run");
    void bar.offsetWidth;
    bar.classList.add("run");
    clearTimeout(sheet._t);
    sheet._t = setTimeout(() => {
      wrap.hidden = true;
      bar.classList.remove("run");
    }, 3000);
  }

  function statusBody() {
    return state.relays.map((on, i) => `R${i + 1}=${on ? 1 : 0}`).join(" ");
  }

  function pushLog(entry) {
    state.log.unshift({
      ...entry,
      at: new Date().toISOString(),
    });
    if (state.log.length > 100) state.log.length = 100;
    save();
    if ($("#view-log").classList.contains("active")) renderLog();
  }

  /**
   * Fake SMS: دستور مثل اپ (R1EN0000) + پاسخ فیک کیت
   */
  function needPhone() {
    if (state.phone && state.phone.length >= 8) return false;
    toast("ژمارەی کیت ڕێک نەخراوە — کلیک بکە");
    openSettings();
    return true;
  }

  function openSettings() {
    fillSettings();
    show("settings");
    setTimeout(() => $("#set-phone")?.focus(), 50);
  }

  function fakeSms(cmd, { title, deviceIndex } = {}) {
    const phone = state.phone;
    if (!phone) {
      return Promise.reject(new Error("no-phone"));
    }

    const body = `${cmd}${state.pin}`.toUpperCase();
    pushLog({
      title: title || `نێردرا بۆ ${cmd}`,
      detail: `→ ${phone}  ·  ${body}`,
      kind: "sent",
      ok: true,
      deviceIndex,
    });
    sheet(`نێردرا بۆ ${cmd}`);

    return new Promise((resolve) => {
      setTimeout(() => {
        let reply = statusBody();
        const mEn = /^R([1-4])EN$/i.exec(cmd);
        const mDs = /^R([1-4])DS$/i.exec(cmd);
        if (mEn) {
          const i = Number(mEn[1]) - 1;
          state.relays[i] = true;
          reply = `R${i + 1} ON OK · ${statusBody()}`;
        } else if (mDs) {
          const i = Number(mDs[1]) - 1;
          state.relays[i] = false;
          reply = `R${i + 1} OFF OK · ${statusBody()}`;
        } else if (/^STATUS$/i.test(cmd)) {
          reply = statusBody();
        }

        state.lastReplyAt = new Date().toISOString();
        save();
        pushLog({
          title: "وەڵام (فیک)",
          detail: `← ${phone}  ·  ${reply}`,
          kind: "reply",
          ok: true,
          deviceIndex,
        });
        resolve(reply);
      }, 1100);
    });
  }

  function syncUiFromRelays() {
    for (let i = 0; i < 4; i++) {
      if (ui[i] === "sending" || ui[i] === "awaiting") continue;
      ui[i] = state.relays[i] ? "on" : "off";
    }
  }

  function chipFor(i) {
    const s = ui[i];
    if (s === "sending") return { label: "لە ناردندایە", color: "var(--tech)", busy: true };
    if (s === "awaiting") return { label: "چاوەڕێی وەڵامی ئامێر", color: "var(--tech)", busy: true };
    if (s === "error") return { label: "هەڵە لە ناردن", color: "var(--danger)", busy: false };
    if (s === "on") return { label: "چالاکە", color: "var(--on)", busy: false };
    return { label: "کوژاوەتەوە", color: "var(--muted)", busy: false };
  }

  function actionLabel(i) {
    const s = ui[i];
    if (s === "sending") return "لە ناردندایە";
    if (s === "awaiting") return "چاوەڕێی وەڵامی ئامێر";
    return state.relays[i] ? "خاموشکردنەوە" : "کردنەوە";
  }

  function renderHome() {
    const onCount = state.relays.filter(Boolean).length;
    $("#home-meta").textContent = `${onCount} لە ٤ · کۆنترۆڵی چوار ئامێر بە پەیام`;
    const banner = $("#setup-banner");
    banner.hidden = !!state.phone;
    $("#signal-pill").querySelector("span").textContent = state.phone ? "DEMO" : "—";

    if (state.lastReplyAt) {
      const t = new Date(state.lastReplyAt);
      const hh = String(t.getHours()).padStart(2, "0");
      const mm = String(t.getMinutes()).padStart(2, "0");
      const el = $("#last-reply");
      el.hidden = false;
      el.textContent = `دوايين وەڵام: ${hh}:${mm}`;
    }

    const grid = $("#fan-grid");
    grid.innerHTML = [0, 1, 2, 3]
      .map((i) => {
        const on = ui[i] === "on" || state.relays[i];
        const busy = ui[i] === "sending" || ui[i] === "awaiting";
        const err = ui[i] === "error";
        const chip = chipFor(i);
        const rotor = on || ui[i] === "awaiting" ? "rotor-on.svg" : "rotor-off.svg";
        const cls = [
          "fan-card",
          on && !busy ? "on" : "",
          busy ? "busy" : "",
          err ? "error" : "",
        ]
          .filter(Boolean)
          .join(" ");

        return `
          <button type="button" class="${cls}" data-i="${i}" aria-pressed="${on}">
            <div class="fan-top">
              <span class="fan-code">R${i + 1}</span>
              <span class="fan-chip" style="color:${chip.color};border-color:color-mix(in srgb, ${chip.color} 28%, transparent);background:color-mix(in srgb, ${chip.color} 10%, transparent)">
                ${chip.busy ? '<i class="spin-dot"></i>' : '<i class="dot"></i>'}
                <span>${esc(chip.label)}</span>
              </span>
            </div>
            <div class="fan-visual">
              <span class="glow"></span>
              <img class="rotor ${on && !busy ? "spin" : ""}" src="${LAYER}/${rotor}" alt="" />
              <img class="cage" src="${LAYER}/cage.svg" alt="" />
              <img class="hub" src="${LAYER}/hub.svg" alt="" />
              <img class="arc" src="${ARC}" alt="" />
            </div>
            <p class="fan-name">${esc(state.names[i])}</p>
            <div class="fan-action">
              <img class="ico" src="${POWER}" alt="" />
              <span>${esc(actionLabel(i))}</span>
            </div>
          </button>`;
      })
      .join("");
  }

  function renderNames() {
    $("#name-rows").innerHTML = state.names
      .map(
        (n, i) => `
      <div class="name-row">
        <span>${esc(DEFAULTS.names[i])}</span>
        <span class="code">R${i + 1}</span>
        <input class="name-input" data-i="${i}" value="${esc(n)}" />
        <img src="kit/icons/svg/edit.svg" class="ico" alt="" />
      </div>`
      )
      .join("");
  }

  function fillSettings() {
    $("#set-phone").value = state.phone;
    $("#set-pin").value = state.pin;
    $("#btn-silent").classList.toggle("on", state.silent);
    $("#btn-silent").setAttribute("aria-pressed", String(state.silent));
    renderNames();
  }

  function renderLog() {
    const items = state.log.filter((e) => {
      if (logFilter === "all") return true;
      if (logFilter === "sent") return e.kind === "sent" || e.kind === "reply";
      if (logFilter === "error") return e.kind === "error" || !e.ok;
      return true;
    });
    $("#empty-log").classList.toggle("visible", items.length === 0);
    $("#log-list").innerHTML = items
      .map((e) => {
        const t = new Date(e.at);
        const time = `${String(t.getHours()).padStart(2, "0")}:${String(t.getMinutes()).padStart(2, "0")}`;
        const badge =
          e.kind === "reply" ? "reply" : e.kind === "error" || !e.ok ? "error" : "sent";
        const badgeText =
          badge === "reply" ? "وەڵام" : badge === "error" ? "هەڵە" : "نێردرا";
        return `
          <li class="log-item">
            <div class="log-thumb"><img src="${FAN_THUMB}" alt="" /></div>
            <div>
              <p class="log-title">${esc(e.title)}</p>
              <p class="log-detail">${esc(e.detail)}</p>
            </div>
            <div class="log-meta">
              <span class="log-time">${time}</span>
              <span class="badge ${badge}">${badgeText}</span>
            </div>
          </li>`;
      })
      .join("");
  }

  async function toggle(i) {
    if (ui[i] === "sending" || ui[i] === "awaiting" || busyAll) return;
    if (needPhone()) return;

    const target = !state.relays[i];
    const cmd = `R${i + 1}${target ? "EN" : "DS"}`;
    ui[i] = "sending";
    renderHome();

    try {
      await fakeSms(cmd, {
        title: `${state.names[i]} — ${target ? "کردنەوە" : "خاموشکردنەوە"}`,
        deviceIndex: i,
      });
      ui[i] = "awaiting";
      renderHome();
      await wait(350);
      ui[i] = target ? "on" : "off";
      renderHome();
    } catch {
      ui[i] = state.relays[i] ? "on" : "off";
      renderHome();
    }
  }

  function wait(ms) {
    return new Promise((r) => setTimeout(r, ms));
  }

  async function allOff() {
    if (busyAll) return;
    if (needPhone()) return;
    const targets = [0, 1, 2, 3].filter((i) => state.relays[i]);
    if (!targets.length) {
      toast("هەموو خاموش");
      return;
    }
    busyAll = true;
    $("#btn-all-off").disabled = true;
    try {
      for (const i of targets) {
        ui[i] = "sending";
        renderHome();
        await fakeSms(`R${i + 1}DS`, {
          title: `${state.names[i]} — خاموشکردنەوە`,
          deviceIndex: i,
        });
        ui[i] = "off";
      }
      toast("هەموو فەنەکان کوژانەوە (فیک)");
    } finally {
      busyAll = false;
      $("#btn-all-off").disabled = false;
      syncUiFromRelays();
      renderHome();
    }
  }

  function goHome() {
    syncUiFromRelays();
    renderHome();
    show("home");
  }

  function route() {
    if (!state.seenSplash) {
      show("splash");
      return;
    }
    goHome();
  }

  // Events
  $("#btn-enter").onclick = () => {
    state.seenSplash = true;
    save();
    goHome();
  };

  $("#setup-banner").onclick = () => openSettings();

  $("#fan-grid").addEventListener("click", (e) => {
    const card = e.target.closest(".fan-card");
    if (!card) return;
    toggle(Number(card.dataset.i));
  });

  $("#btn-all-off").onclick = allOff;
  $("#btn-open-settings").onclick = () => openSettings();
  $("#btn-settings-back").onclick = () => goHome();

  $("#btn-toggle-pin").onclick = () => {
    const inp = $("#set-pin");
    const show = inp.type === "password";
    inp.type = show ? "text" : "password";
    $("#pin-eye").src = show ? "kit/icons/svg/eye-off.svg" : "kit/icons/svg/eye.svg";
  };

  $("#btn-silent").onclick = () => {
    state.silent = !state.silent;
    $("#btn-silent").classList.toggle("on", state.silent);
    $("#btn-silent").setAttribute("aria-pressed", String(state.silent));
  };

  $("#btn-settings-save").onclick = () => {
    const phone = digits($("#set-phone").value);
    let pin = digits($("#set-pin").value).replace(/\D/g, "");
    if (pin.length !== 4) pin = "0000";
    if (phone.length < 8) {
      toast("ژمارەی مۆبایل دروست بنووسە", true);
      return;
    }
    state.phone = phone;
    state.pin = pin;
    state.names = $$(".name-input").map((el, i) => el.value.trim() || DEFAULTS.names[i]);
    save();
    toast("پاشەکەوت کرا");
    goHome();
  };

  $("#btn-test").onclick = async () => {
    const phone = digits($("#set-phone").value) || state.phone;
    if (phone.length < 8) {
      toast("ژمارە بنووسە", true);
      return;
    }
    state.phone = phone;
    state.pin = digits($("#set-pin").value).replace(/\D/g, "").padEnd(4, "0").slice(0, 4) || "0000";
    if (state.pin.length !== 4) state.pin = "0000";
    save();
    toast("تاقیکردنەوە…");
    await fakeSms("STATUS", { title: "تاقیکردنەوەی پەیوەندی" });
    toast("وەڵامی فیک هات — OK");
  };

  $("#btn-open-log").onclick = () => {
    renderLog();
    show("log");
  };
  $("#btn-log-back").onclick = () => goHome();
  $("#btn-clear-log").onclick = () => {
    state.log = [];
    save();
    renderLog();
  };

  $$("#log-filters .chip").forEach((chip) => {
    chip.onclick = () => {
      $$("#log-filters .chip").forEach((c) => c.classList.remove("active"));
      chip.classList.add("active");
      logFilter = chip.dataset.filter;
      renderLog();
    };
  });

  $("#sheet").onclick = (e) => {
    if (e.target.id === "sheet") $("#sheet").hidden = true;
  };

  // Boot
  for (let i = 0; i < 4; i++) ui[i] = state.relays[i] ? "on" : "off";
  route();
})();
