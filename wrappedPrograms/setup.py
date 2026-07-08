import gi
gi.require_version("Gtk", "3.0")
from gi.repository import Gtk, GLib, Gdk, GdkPixbuf, Pango
import os, sys, subprocess, getpass, threading, re, shutil, json

GLib.set_prgname("niri-setup")

CSS = b"""
window {
    color: #e6e1cf;
    border-radius: 16px;
}
.strength-bar { min-height: 2px; margin: 2px 0; }
.strength-bar trough { min-height: 2px; border-radius: 1px; background: #22232d; border: none; }
.strength-bar trough progress { min-height: 2px; border-radius: 1px; border: none; }
.strength-bar.weak trough progress { background: #e74c3c; }
.strength-bar.ok trough progress { background: #f1c40f; }
.strength-bar.strong trough progress { background: #2ecc71; }
.face-btn { padding:0; border-radius:50%; background:transparent; border:2px dotted #555; }
.face-btn:hover { border-color:#3584e4; background:rgba(53,132,228,0.08); }
.face-btn image { margin:0; }
.title { font-size:20px; font-weight:700; margin-bottom:2px; }
.subtitle { font-size:13px; opacity:.65; margin-bottom:16px; }
.step-label { font-size:12px; opacity:.6; }
entry { caret-color: #e6e1cf; border-color: #333; border-radius:6px; padding:4px 8px; }
entry:focus { border-color: #555; box-shadow: none; }
.browser-row { padding:8px 12px; border-radius:8px; }
.browser-row:hover { background:rgba(53,132,228,0.06); }
.browser-row:selected { background:rgba(53,132,228,0.15); border:1px solid #3584e4; }
.browser-row.installed radio:disabled { color: #4CAF50; }
.browser-row.installed radio:disabled:checked { color: #4CAF50; }
.status-text { font-size:14px; }
.done-icon { font-size:48px; }
.entry-error { border-color:#e74c3c; border-width:1.5px; }
.tile { border-radius:12px; padding:6px 2px; border:2px solid transparent; background:rgba(255,255,255,0.03); }
.tile:hover { border-color:#555; background:rgba(255,255,255,0.06); }
.tile-done { border-color:#2ecc71; }
.tile-on { border-color:#3584e4; background:rgba(53,132,228,0.1); }
button.suggested-action { background:#3584e4; color:#fff; border:none; border-radius:8px; padding:6px 20px; font-weight:600; }
button.suggested-action:hover { background:#4a94f0; }
button.suggested-action:disabled { background:#33343d; color:#666; }
button.outlined { background:transparent; border:1px solid #555; color:#e6e1cf; border-radius:8px; padding:6px 20px; }
button.outlined:hover { background:rgba(255,255,255,0.06); }
.icon-badge { background:#3584e4; border-radius:12px; }
"""

def load_css():
    p = Gtk.CssProvider()
    p.load_from_data(CSS)
    Gtk.StyleContext.add_provider_for_screen(Gdk.Screen.get_default(), p, 600)

NIXCONF = os.path.expanduser("~/nixconf")
USER_CONFIG = os.path.join(NIXCONF, "user-config")

def _dict_to_nix(d, indent=0):
    pad = "  " * indent
    inner = "  " * (indent + 1)
    items = []
    for k, v in d.items():
        if isinstance(v, bool):
            items.append(f"{inner}{k} = {'true' if v else 'false'};")
        elif isinstance(v, str):
            v = v.replace("\\", "\\\\").replace("\"", "\\\"").replace("\n", "\\n")
            items.append(f'{inner}{k} = "{v}";')
        elif v is None:
            items.append(f"{inner}{k} = null;")
        elif isinstance(v, (int, float)):
            items.append(f"{inner}{k} = {v};")
    return "{\n" + "\n".join(items) + f"\n{pad}}}"

class SetupWizard(Gtk.Window):
    def __init__(self):
        super().__init__(decorated=False, title="mujō Setup")
        self.set_default_size(624, 576)
        self.set_resizable(False)
        self.set_position(Gtk.WindowPosition.CENTER)
        self.set_type_hint(Gdk.WindowTypeHint.DIALOG)

        rgba = self.get_screen().get_rgba_visual()
        if rgba:
            self.set_visual(rgba)
        self.set_app_paintable(True)
        self.connect("draw", self._on_draw_background)

        self.face = os.path.expanduser("~/.face")
        self.passwd = ""
        self.browser_id = ""
        self.browser_label = ""
        self.social_id = ""
        self.social_label = ""
        self.sops_age_key = ""
        self.sops_pubkey = ""
        self.connection_data = {}
        self.github_repo = ""
        self.github_token = ""
        self.persist_enabled = False
        self._nixconf = os.path.expanduser("~/nixconf")
        self._secrets = os.path.join(self._nixconf, "secrets")
        self._existing = self._load_existing_config()
        self._build()

    def _build(self):
        load_css()
        vbox = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=0)
        self.add(vbox)

        self.step_lbl = Gtk.Label(xalign=0)
        self.step_lbl.get_style_context().add_class("step-label")
        self.step_lbl.set_margin_top(14)
        self.step_lbl.set_margin_bottom(4)
        self.step_lbl.set_margin_start(20)
        vbox.pack_start(self.step_lbl, False, False, 0)

        self.stack = Gtk.Stack()
        self.stack.set_transition_type(Gtk.StackTransitionType.SLIDE_LEFT_RIGHT)
        self.stack.set_transition_duration(200)
        vbox.pack_start(self.stack, True, True, 0)

        self.pg_welcome = WelcomePage(self)
        self.pg_browser = BrowserPage(self)
        self.pg_social = SocialPage(self)
        self.pg_sops = SopsPage(self)
        self.pg_connection = ConnectionPage(self)
        self.pg_github = GitHubPage(self)
        self.pg_token = TokenPage(self)
        self.pg_persist = PersistPage(self)
        self.pg_apply = ApplyPage(self)
        self.pg_done = DonePage(self)

        if "connection" in self._existing:
            self.pg_connection.set_initial_values(self._existing["connection"])
        if "github" in self._existing:
            self.pg_github.set_initial_values(self._existing["github"])
            self.pg_token.set_initial_values(self._existing["github"])
        if "persist" in self._existing:
            self.pg_persist.set_initial_values(self._existing["persist"])

        self.stack.add_named(self.pg_welcome, "welcome")
        self.stack.add_named(self.pg_browser, "browser")
        self.stack.add_named(self.pg_social, "social")
        self.stack.add_named(self.pg_sops, "sops")
        self.stack.add_named(self.pg_connection, "connection")
        self.stack.add_named(self.pg_github, "github")
        self.stack.add_named(self.pg_token, "token")
        self.stack.add_named(self.pg_persist, "persist")
        self.stack.add_named(self.pg_apply, "apply")
        self.stack.add_named(self.pg_done, "done")

        sep = Gtk.Separator(orientation=Gtk.Orientation.HORIZONTAL)
        vbox.pack_start(sep, False, False, 0)

        bb = Gtk.Box(spacing=6, margin_top=8, margin_bottom=10,
                     margin_start=16, margin_end=16)
        self.btn_back = Gtk.Button(label="_Back", use_underline=True)
        self.btn_back.get_style_context().add_class("outlined")
        self.btn_next = Gtk.Button(label="_Next", use_underline=True)
        self.btn_cancel = Gtk.Button(label="_Cancel", use_underline=True)
        self.btn_cancel.get_style_context().add_class("outlined")
        self.btn_skip = Gtk.Button(label="_Skip", use_underline=True)
        self.btn_skip.get_style_context().add_class("outlined")
        self.btn_next.get_style_context().add_class("suggested-action")

        self.btn_back.connect("clicked", lambda *_: self._on_back())
        self.btn_next.connect("clicked", lambda *_: self._on_next())
        self.btn_cancel.connect("clicked", lambda *_: self._on_cancel())
        self.btn_skip.connect("clicked", lambda *_: self._on_skip())

        bb.pack_start(self.btn_back, False, False, 0)
        bb.pack_start(self.btn_skip, False, False, 0)
        bb.pack_end(self.btn_cancel, False, False, 0)
        bb.pack_end(self.btn_next, False, False, 0)
        vbox.pack_end(bb, False, False, 0)

        self._show("welcome")

    def _load_existing_config(self):
        cfg = {}
        conf_dir = os.path.join(os.environ.get("XDG_CONFIG_HOME",
                                 os.path.expanduser("~/.config")), "niri-setup")
        github = self._load_encrypted_json(os.path.join(conf_dir, "github.json"))
        if github:
            cfg["github"] = github
        connection = self._load_encrypted_json(os.path.join(conf_dir, "connection.json"))
        if connection:
            cfg["connection"] = connection
        persist_path = os.path.join(conf_dir, "persist-backup.json")
        if os.path.isfile(persist_path):
            try:
                with open(persist_path) as f:
                    cfg["persist"] = json.load(f)
            except Exception:
                pass
        sops_path = os.path.join(self._nixconf, ".sops.yaml")
        if os.path.isfile(sops_path):
            try:
                with open(sops_path) as f:
                    cfg["sops_pubkey"] = f.read()
            except Exception:
                pass
        return cfg

    def _load_encrypted_json(self, path):
        try:
            r = subprocess.run(
                ["sops", "--decrypt", path],
                capture_output=True, timeout=10,
            )
            if r.returncode == 0:
                return json.loads(r.stdout)
        except Exception:
            pass
        if os.path.isfile(path):
            try:
                with open(path) as f:
                    return json.load(f)
            except Exception:
                pass
        return None

    def _save_encrypted_json(self, path, data, age_pubkey=None):
        pk = age_pubkey or self.sops_pubkey
        if not pk:
            with open(path, "w") as f:
                json.dump(data, f)
            return
        tmp = path + ".tmp"
        with open(tmp, "w") as f:
            json.dump(data, f)
        try:
            r = subprocess.run(
                ["sops", "--encrypt", "--age", pk, "-o", path, tmp],
                capture_output=True, timeout=10,
            )
            if r.returncode == 0:
                os.unlink(tmp)
                return
        except Exception as e:
            print(f"[SETUP] sops encrypt error: {e}")
        os.replace(tmp, path)

    def _on_draw_background(self, widget, cr):
        cr.set_source_rgba(34/255, 35/255, 45/255, 0.8)
        cr.paint()
        return False  # let child widgets draw normally

    def _show(self, name, _skip_auto=False, **kw):
        if not _skip_auto:
            if name == "browser" and self.pg_browser.all_installed():
                self._show("social")
                return
            if name == "social" and self.pg_social.all_installed():
                self._show("sops")
                return
        self.stack.set_visible_child_name(name)
        self._update_buttons()
        if name == "welcome":
            self.step_lbl.set_markup("Step <b>1</b> of 9:  Account")
        elif name == "browser":
            self.step_lbl.set_markup("Step <b>2</b> of 9:  Browser")
        elif name == "social":
            self.step_lbl.set_markup("Step <b>3</b> of 9:  Social")
        elif name == "sops":
            self.step_lbl.set_markup("Step <b>4</b> of 9:  Encryption")
        elif name == "connection":
            self.step_lbl.set_markup("Step <b>5</b> of 9:  Connection")
        elif name == "github":
            self.step_lbl.set_markup("Step <b>6</b> of 9:  Repository")
        elif name == "token":
            self.step_lbl.set_markup("Step <b>7</b> of 9:  Token")
        elif name == "persist":
            self.step_lbl.set_markup("Step <b>8</b> of 9:  Data Backup")
        elif name == "apply":
            self.step_lbl.set_markup("Step <b>9</b> of 9:  Applying\u2026")
        elif name == "done":
            self.step_lbl.set_markup("")

    def _update_buttons(self):
        n = self.stack.get_visible_child_name()
        selection = ("browser", "social", "sops", "connection", "github", "token", "persist")
        self.btn_back.set_visible(n in selection)
        self.btn_skip.set_visible(n in ("browser", "social", "sops", "connection", "token", "persist"))
        self.btn_next.set_visible(n in ("welcome", *selection, "done"))
        self.btn_cancel.set_visible(n in ("welcome", *selection))
        if n == "persist":
            self.btn_next.set_label("A_pply")
        elif n == "done":
            self.btn_next.set_label("_Finish")
        else:
            self.btn_next.set_label("_Next")
        valid = True
        if n == "welcome":
            valid = self.pg_welcome.is_valid()
        elif n == "browser":
            valid = self.pg_browser.get_selected() is not None
        elif n == "social":
            valid = self.pg_social.get_selected() is not None
        self.btn_next.set_sensitive(valid)
        ctx = self.btn_next.get_style_context()
        if valid:
            ctx.add_class("suggested-action")
        else:
            ctx.remove_class("suggested-action")

    def _on_next(self):
        n = self.stack.get_visible_child_name()
        if n == "welcome":
            ok, msg = self.pg_welcome.validate()
            if not ok:
                if msg:
                    self._err(msg)
                return
            self.passwd = self.pg_welcome.pw
            self.pg_welcome.save_face()
            self._show("browser")
        elif n == "browser":
            r = self.pg_browser.get_selected()
            if not r:
                self._err("Select a browser or go back.")
                return
            self.browser_id, self.browser_label = r
            self._show("social")
        elif n == "social":
            r = self.pg_social.get_selected()
            if not r:
                self._err("Select an app or skip.")
                return
            self.social_id, self.social_label = r
            self._show("sops")
        elif n == "sops":
            self.sops_age_key, self.sops_pubkey = self.pg_sops.get_result()
            self._show("connection")
        elif n == "connection":
            self.connection_data = self.pg_connection.get_result()
            self._show("github")
        elif n == "github":
            repo = self.pg_github.get_result()
            if not repo:
                self.github_repo = ""
                self.github_token = ""
                self._show("persist")
                return
            if not self.pg_github.validate():
                return
            self.github_repo = repo
            self._show("token")
        elif n == "token":
            self.github_token = self.pg_token.get_result()
            self._show("persist")
        elif n == "persist":
            self.persist_enabled = self.pg_persist.get_result()
            self._show("apply")
            GLib.idle_add(self._do_apply)
        elif n == "done":
            self._on_cancel()

    def _err(self, msg):
        d = Gtk.MessageDialog(transient_for=self, flags=0,
                              message_type=Gtk.MessageType.ERROR,
                              buttons=Gtk.ButtonsType.OK, text=msg)
        d.run()
        d.destroy()

    def _on_cancel(self):
        Gtk.main_quit()

    def _on_back(self):
        n = self.stack.get_visible_child_name()
        prev = {"browser": "welcome", "social": "browser", "sops": "social", "connection": "sops", "github": "connection", "token": "github", "persist": "token"}
        target = prev.get(n, "welcome")
        # Skip back past pages with nothing to choose
        while target in ("browser", "social"):
            if target == "browser" and self.pg_browser.all_installed():
                target = prev.get(target, "welcome")
            elif target == "social" and self.pg_social.all_installed():
                target = prev.get(target, "welcome")
            else:
                break
        self._show(target, _skip_auto=True)

    def _on_skip(self):
        n = self.stack.get_visible_child_name()
        if n == "browser":
            self.browser_id = ""
            self.browser_label = ""
            self._show("social")
        elif n == "social":
            self.social_id = ""
            self.social_label = ""
            self._show("sops")
        elif n == "sops":
            self.sops_age_key = ""
            self.sops_pubkey = ""
            self._show("connection")
        elif n == "connection":
            self.connection_data = {}
            self._show("github")
        elif n == "token":
            self.github_token = ""
            self._show("persist")
        elif n == "persist":
            self.persist_enabled = False
            self._show("apply")
            GLib.idle_add(self._do_apply)

    def _do_apply(self):
        t = threading.Thread(target=self._apply_worker, daemon=True)
        t.start()

    def _apply_worker(self):
        print("[SETUP] Setting password")
        self.pg_apply.update("Setting password\u2026", False)
        p = subprocess.run(
            ["sudo", "-S", "chpasswd"],
            input=f"{getpass.getuser()}:{self.passwd}",
            capture_output=True, text=True,
        )
        if p.returncode != 0:
            self.pg_apply.update("Failed to set password", True)
            print("[SETUP] FAILED: password")
            return
        self.pg_apply.update("Password set", False)
        print("[SETUP] Password set")

        if self.browser_id:
            print(f"[SETUP] Installing {self.browser_id}...")
            self.pg_apply.update(f"Installing {self.browser_label}\u2026", False)
            p = subprocess.run(
                ["flatpak", "install", "-y", "flathub", self.browser_id],
                capture_output=True, text=True,
            )
            ok = p.returncode == 0 or "already installed" in (p.stderr or "").lower()
            if ok:
                self.pg_apply.update(f"{self.browser_label} installed", False)
                print(f"[SETUP] {self.browser_label} installed")
            else:
                self.pg_apply.update(f"Failed to install {self.browser_label}", True)
                print(f"[SETUP] FAILED: {self.browser_label}")
                return
        else:
            self.pg_apply.update("Skipped browser install", False)
            print("[SETUP] Skipped browser install")

        if self.social_id:
            print(f"[SETUP] Installing {self.social_id}...")
            self.pg_apply.update(f"Installing {self.social_label}\u2026", False)
            p = subprocess.run(
                ["flatpak", "install", "-y", "flathub", self.social_id],
                capture_output=True, text=True,
            )
            ok = p.returncode == 0 or "already installed" in (p.stderr or "").lower()
            if ok:
                self.pg_apply.update(f"{self.social_label} installed", False)
                print(f"[SETUP] {self.social_label} installed")
            else:
                self.pg_apply.update(f"Failed to install {self.social_label}", True)
                print(f"[SETUP] FAILED: {self.social_label}")
                return
        else:
            self.pg_apply.update("Skipped social apps install", False)
            print("[SETUP] Skipped social apps install")

        if self.sops_age_key:
            print("[SETUP] Setting up SOPS age key...")
            self.pg_apply.update("Setting up SOPS age key\u2026", False)
            key_dir = os.path.expanduser("~/.config/sops/age")
            os.makedirs(key_dir, exist_ok=True)
            key_path = os.path.join(key_dir, "keys.txt")
            try:
                with open(key_path, "w") as f:
                    f.write(self.sops_age_key)
                if self.sops_pubkey:
                    sops_yaml = f"""keys:
  - &user {self.sops_pubkey}
creation_rules:
  - path_regex: secrets/.*$
    key_groups:
      - age:
          - *user
"""
                    repo_yaml = os.path.join(os.path.expanduser("~/nixconf"), ".sops.yaml")
                    with open(repo_yaml, "w") as f:
                        f.write(sops_yaml)
                self.pg_apply.update("SOPS encryption configured", False)
                print("[SETUP] SOPS configured")
            except Exception as e:
                self.pg_apply.update(f"SOPS setup failed: {e}", True)
                print(f"[SETUP] FAILED: SOPS {e}")
                return
        else:
            self.pg_apply.update("Skipped SOPS setup", False)
            print("[SETUP] Skipped SOPS setup")

        if self.connection_data:
            print("[SETUP] Saving connection config...")
            self.pg_apply.update("Saving connection config\u2026", False)
            conf_dir = os.path.join(os.environ.get("XDG_CONFIG_HOME",
                                     os.path.expanduser("~/.config")), "niri-setup")
            os.makedirs(conf_dir, exist_ok=True)
            try:
                self._save_encrypted_json(
                    os.path.join(conf_dir, "connection.json"),
                    self.connection_data,
                )
                self.pg_apply.update("Connection config saved (encrypted)", False)
                print("[SETUP] Connection config saved (encrypted)")
            except Exception as e:
                self.pg_apply.update(f"Connection config failed: {e}", True)
                print(f"[SETUP] FAILED: connection {e}")
                return
        else:
            self.pg_apply.update("Skipped connection setup", False)
            print("[SETUP] Skipped connection setup")

        # Write user-config files for Nix to consume at build time
        try:
            os.makedirs(USER_CONFIG, exist_ok=True)
            username = "yurii"
            with open(os.path.join(USER_CONFIG, "_user.nix"), "w") as f:
                f.write('{ name = "%s"; }\n' % username)
            connection_data = self.connection_data or {}
            conn_fields = {"git_user", "git_email", "hostname", "wifi_ssid", "wifi_password", "tailscale"}
            nix_conn = {k: v for k, v in connection_data.items() if k in conn_fields}
            with open(os.path.join(USER_CONFIG, "_connection.nix"), "w") as f:
                f.write(_dict_to_nix(nix_conn) + "\n")
            git_data = {
                "name": connection_data.get("git_user", connection_data.get("name", "User")),
                "email": connection_data.get("git_email", connection_data.get("email", "user@email.com")),
            }
            with open(os.path.join(USER_CONFIG, "_git.nix"), "w") as f:
                f.write(_dict_to_nix(git_data) + "\n")
            api_keys = {k: v for k, v in connection_data.items() if k in ("openai", "anthropic", "gemini", "openrouter") and v}
            if api_keys:
                persist_api = os.path.join("/persist", "openrouterapi")
                or_key = api_keys.get("openrouter")
                if or_key:
                    os.makedirs(os.path.dirname(persist_api), exist_ok=True)
                    with open(persist_api, "w") as f:
                        f.write(or_key.strip())
                with open(os.path.join(USER_CONFIG, "api-keys.nix"), "w") as f:
                    f.write(_dict_to_nix(api_keys) + "\n")
            print("[SETUP] User config written to ~/nixconf/user-config/")
        except Exception as e:
            print(f"[SETUP] WARNING: Failed to write user-config: {e}")

        if self.github_repo and self.github_token:
            print(f"[SETUP] Saving GitHub config for {self.github_repo}...")
            self.pg_apply.update("Saving GitHub config\u2026", False)
            conf_dir = os.path.join(os.environ.get("XDG_CONFIG_HOME",
                                     os.path.expanduser("~/.config")), "niri-setup")
            os.makedirs(conf_dir, exist_ok=True)
            try:
                self._save_encrypted_json(
                    os.path.join(conf_dir, "github.json"),
                    {"repo": self.github_repo, "token": self.github_token},
                )
                self.pg_apply.update("GitHub config saved (encrypted)", False)
                print("[SETUP] GitHub config saved")
            except Exception as e:
                self.pg_apply.update(f"GitHub config failed: {e}", True)
                print(f"[SETUP] FAILED: GitHub {e}")
                return
        else:
            self.pg_apply.update("Skipped GitHub setup", False)
            print("[SETUP] Skipped GitHub setup")

        if self.persist_enabled and self.persist_enabled.get("enabled"):
            print(f"[SETUP] Saving persistent backup config...")
            self.pg_apply.update("Saving backup config\u2026", False)
            conf_dir = os.path.join(os.environ.get("XDG_CONFIG_HOME",
                                     os.path.expanduser("~/.config")), "niri-setup")
            os.makedirs(conf_dir, exist_ok=True)
            try:
                with open(os.path.join(conf_dir, "persist-backup.json"), "w") as f:
                    json.dump(self.persist_enabled, f)
                self.pg_apply.update("Backup config saved", False)
                print("[SETUP] Backup config saved")
            except Exception as e:
                self.pg_apply.update(f"Backup config failed: {e}", True)
                print(f"[SETUP] FAILED: backup config {e}")
                return
        else:
            self.pg_apply.update("Skipped backup setup", False)
            print("[SETUP] Skipped backup setup")

        flag = os.path.join(os.environ.get("XDG_CACHE_HOME",
                                           os.path.expanduser("~/.cache")),
                            "niri-setup-done")
        os.makedirs(os.path.dirname(flag), exist_ok=True)
        open(flag, "w").close()

        parts = []
        if self.browser_label:
            parts.append(f"{self.browser_label}")
        if self.social_label:
            parts.append(f"{self.social_label}")
        result = " and ".join(parts) if parts else "nothing"
        GLib.idle_add(lambda: self._show("done"))
        GLib.idle_add(self.pg_done.set_result, result)
        print(f"[SETUP] Done: {result}")

    def run(self):
        self.show_all()
        self._update_buttons()
        Gtk.main()


def _circular_avatar_pixbuf(px, size, pad_px=2):
    """Crop top-center, resize, add padding, output circular avatar with alpha."""
    from gi.repository import GdkPixbuf
    w, h = px.get_width(), px.get_height()
    s = min(w, h)
    x = (w - s) // 2
    y = 0
    inner_size = size - 2 * pad_px
    avatar = px.new_subpixbuf(x, y, s, s).scale_simple(inner_size, inner_size, GdkPixbuf.InterpType.BILINEAR)
    final = GdkPixbuf.Pixbuf.new(colorspace=GdkPixbuf.Colorspace.RGB, has_alpha=True, bits_per_sample=8,
                                 width=size, height=size)
    final.fill(0)  # transparent
    avatar.copy_area(0, 0, inner_size, inner_size, final, pad_px, pad_px)
    # Apply circular mask
    import array
    pixels = bytearray(final.get_pixels())
    rowstride = final.get_rowstride()
    n_channels = final.get_n_channels()
    cx = size // 2
    cy = size // 2
    r = inner_size // 2
    for py in range(size):
        for px_ in range(size):
            if (px_ - cx) ** 2 + (py - cy) ** 2 > r ** 2:
                offset = py * rowstride + px_ * n_channels + 3
                pixels[offset] = 0
    final = GdkPixbuf.Pixbuf.new_from_data(
        bytes(pixels), final.get_colorspace(), True, 8, size, size, final.get_rowstride()
    )
    return final


class WelcomePage(Gtk.Box):
    def __init__(self, wiz):
        super().__init__(orientation=Gtk.Orientation.VERTICAL, spacing=0)
        self.wiz = wiz
        self.pw = ""
        self._pic_path = None
        self._face_pixbuf = None
        self.has_custom_face = False

        self.set_margin_start(28)
        self.set_margin_end(28)
        self.set_margin_top(8)

        # Pre-load toggle icons so first click is instant
        for name in ("view-reveal-symbolic", "view-conceal-symbolic"):
            try:
                Gtk.IconTheme.get_default().load_icon(name, 16, 0)
            except Exception:
                pass

        # Lock icon badge
        badge = Gtk.Box(halign=Gtk.Align.CENTER, valign=Gtk.Align.CENTER)
        badge.get_style_context().add_class("icon-badge")
        badge.set_size_request(48, 48)
        icon = Gtk.Image.new_from_icon_name("dialog-password-symbolic", Gtk.IconSize.DIALOG)
        badge.pack_start(icon, True, True, 0)
        self.pack_start(badge, False, False, 0)

        lbl = Gtk.Label(xalign=0.5, margin_top=8)
        lbl.set_markup("<span size='xx-large' weight='bold'>Welcome to <span color='#59C2FF'>mujō</span></span>")
        self.pack_start(lbl, False, False, 0)

        lbl2 = Gtk.Label(xalign=0.5, label="Configure your system to get started.")
        lbl2.get_style_context().add_class("subtitle")
        self.pack_start(lbl2, False, False, 0)

        # Profile pic
        pw = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=4)

        self.face_btn = Gtk.Button()
        self.face_btn.get_style_context().add_class("face-btn")
        self.face_btn.set_size_request(100, 100)
        self.face_btn.set_halign(Gtk.Align.CENTER)
        self.face_btn.set_valign(Gtk.Align.CENTER)
        self.face_btn.set_hexpand(False)
        self.face_btn.set_vexpand(False)

        # If ~/.face exists and is a valid image, load and preview it cropped/rounded
        import os
        from gi.repository import GdkPixbuf
        print('[DEBUG] WelcomePage: Init, checking ~/.face...')
        try:
            face_path = os.path.expanduser("~/.face")
            print('[DEBUG] Checking for face file:', face_path)
            if os.path.isfile(face_path):
                print('[DEBUG] .face exists, size:', os.path.getsize(face_path))
            if os.path.isfile(face_path) and os.path.getsize(face_path) > 0:
                px = GdkPixbuf.Pixbuf.new_from_file(face_path)
                print('[DEBUG] Loaded pixbuf:', px.get_width(), px.get_height(), px.get_has_alpha())
                px = _circular_avatar_pixbuf(px, 100, 2)
                self._face_pixbuf = px
                self.face_img = Gtk.Image.new_from_pixbuf(px)
                self.face_btn.set_image(self.face_img)
                print('[DEBUG] Displaying cropped ~/.face image')
            else:
                px = Gtk.IconTheme.get_default().load_icon("avatar-default-symbolic", 100, 0)
                px = _circular_avatar_pixbuf(px, 100, 2)
                self._face_pixbuf = px
                self.face_img = Gtk.Image.new_from_pixbuf(px)
                self.face_btn.set_image(self.face_img)
                print('[DEBUG] Falling back to default icon (file missing or empty)')
        except Exception as e:
            print('[DEBUG] Failed to load ~/.face:', e)
            px = Gtk.IconTheme.get_default().load_icon("avatar-default-symbolic", 100, 0)
            px = _circular_avatar_pixbuf(px, 100, 2)
            self._face_pixbuf = px
            self.face_img = Gtk.Image.new_from_pixbuf(px)
            self.face_btn.set_image(self.face_img)


        self.face_btn.set_image_position(Gtk.PositionType.TOP)
        self.face_img.set_pixel_size(64)

        self.face_btn.connect("clicked", self._pick_pic)
        # ponytail: don't reset to default icon after photo pick
        orig_set_image = self.face_btn.set_image
        def set_image_once(img):
            if not self.has_custom_face:
                orig_set_image(img)
        self.face_btn.set_image = set_image_once
        pw.pack_start(self.face_btn, False, False, 0)
        # force parent Box not to expand
        pw.set_halign(Gtk.Align.CENTER)
        pw.set_hexpand(False)
        pw.set_valign(Gtk.Align.CENTER)
        pw.set_vexpand(False)

        self.pack_start(pw, False, False, 0)
        self.set_halign(Gtk.Align.FILL)
        self.set_valign(Gtk.Align.START)
        self.set_hexpand(True)
        self.set_vexpand(False)

        # Spacer
        self.pack_start(Gtk.Box(), True, True, 0)
        self.pack_start(Gtk.Box(), False, False, 0)

        # Password
        gf = Gtk.Grid(row_spacing=6, column_spacing=10, margin_top=40)
        gf.set_hexpand(False)
        gf.set_halign(Gtk.Align.CENTER)

        def mk_entry(placeholder, visibility, show_toggle=False):
            e = Gtk.Entry()
            e.set_placeholder_text(placeholder)
            e.set_visibility(visibility)
            e.set_width_chars(34)
            if show_toggle:
                e.set_icon_from_icon_name(Gtk.EntryIconPosition.SECONDARY, "view-reveal-symbolic")
                e.connect("icon-press", self._toggle_visibility)
                e._visible = False
            return e

        self.pw_entry = mk_entry("Password", False, show_toggle=True)
        self.cf_entry = mk_entry("Confirm password", False)
        self.pw_entry.connect("changed", self._pw_changed)
        self.cf_entry.connect("changed", self._cf_changed)

        self.match_lbl = Gtk.Label(xalign=0.5)
        self.match_lbl.set_markup('<span color="#e74c3c" size="small">Passwords do not match</span>')
        self.match_lbl.set_no_show_all(True)

        self.level = Gtk.ProgressBar()
        self.level.get_style_context().add_class("strength-bar")

        gf.attach(self.pw_entry, 0, 0, 2, 1)
        gf.attach(self.level, 0, 1, 2, 1)
        gf.attach(self.cf_entry, 0, 2, 2, 1)
        gf.attach(self.match_lbl, 0, 3, 2, 1)
        self.pack_start(gf, False, False, 0)
        self.pack_start(Gtk.Box(), True, True, 0)

    def is_valid(self):
        pw = self.pw_entry.get_text()
        cf = self.cf_entry.get_text()
        return len(pw) > 0 and pw == cf

    def _toggle_visibility(self, entry, pos, *a):
        entry._visible = not entry._visible
        entry.set_visibility(entry._visible)
        entry.set_icon_from_icon_name(Gtk.EntryIconPosition.SECONDARY,
                                      "view-conceal-symbolic" if entry._visible else "view-reveal-symbolic")
        while Gtk.events_pending():
            Gtk.main_iteration()

    def _pw_changed(self, *a):
        s = self._strength(self.pw_entry.get_text())
        self.level.set_fraction(s / 100.0)
        ctx = self.level.get_style_context()
        for c in ("weak", "ok", "strong"):
            ctx.remove_class(c)
        if s < 40:
            ctx.add_class("weak")
        elif s < 70:
            ctx.add_class("ok")
        else:
            ctx.add_class("strong")
        self._check_match()
        self.wiz._update_buttons()

    def _cf_changed(self, *a):
        self._check_match()
        self.wiz._update_buttons()

    def _check_match(self):
        pw = self.pw_entry.get_text()
        cf = self.cf_entry.get_text()
        ctx = self.cf_entry.get_style_context()
        if cf and pw != cf:
            ctx.add_class("entry-error")
            self.match_lbl.show()
            return False
        ctx.remove_class("entry-error")
        self.match_lbl.hide()
        return True

    def _strength(self, pw):
        s = 0
        if len(pw) >= 8:  s += 25
        if len(pw) >= 12: s += 15
        if re.search(r"[a-z]", pw): s += 15
        if re.search(r"[A-Z]", pw): s += 15
        if re.search(r"[0-9]", pw): s += 15
        if re.search(r"[^a-zA-Z0-9]", pw): s += 15
        return min(s, 100)

    def _pick_pic(self, *a):
        d = Gtk.FileChooserDialog(title="Select Profile Picture",
                                   transient_for=self.wiz,
                                   action=Gtk.FileChooserAction.OPEN)
        d.add_button("_Cancel", Gtk.ResponseType.CANCEL)
        d.add_button("_Open", Gtk.ResponseType.OK)
        f = Gtk.FileFilter()
        f.set_name("Images")
        for e in ("*.png", "*.jpg", "*.jpeg", "*.gif", "*.bmp", "*.svg", "*.webp"):
            f.add_pattern(e)
        d.add_filter(f)
        if d.run() == Gtk.ResponseType.OK:
            self._pic_path = d.get_filename()
            try:
                px = GdkPixbuf.Pixbuf.new_from_file(self._pic_path)
                px = _circular_avatar_pixbuf(px, 100, 2)
                self._face_pixbuf = px
                # ponytail: literally replace the button so icon can never revert
                parent = self.face_btn.get_parent()
                self.face_btn.destroy()
                self.face_btn = Gtk.Button()
                self.face_btn.get_style_context().add_class("face-btn")
                self.face_btn.set_size_request(100, 100)
                self.face_btn.set_relief(Gtk.ReliefStyle.NONE)
                self.face_btn.set_halign(Gtk.Align.CENTER)
                self.face_btn.set_valign(Gtk.Align.CENTER)
                self.face_btn.set_hexpand(False)
                self.face_btn.set_vexpand(False)
                img = Gtk.Image.new_from_pixbuf(px)
                img.set_pixel_size(64)
                self.face_btn.add(img)
                self.face_btn.show_all()
                self.face_btn.connect("clicked", self._pick_pic)
                parent.pack_start(self.face_btn, False, False, 0)
                parent.show_all()
                self.has_custom_face = True
            except Exception:
                pass
        d.destroy()

    def save_face(self):
        if self._face_pixbuf:
            try:
                w = self._face_pixbuf.get_width()
                pad = 2
                inner = self._face_pixbuf.new_subpixbuf(pad, pad, w - 2*pad, w - 2*pad)
                print('[DEBUG] Saving face to:', self.wiz.face)
                inner.savev(self.wiz.face, "png", [], [])
                print('[DEBUG] Face saved successfully')
            except PermissionError as e:
                print('[DEBUG] PermissionError saving face:', e)
                if hasattr(self.wiz, '_err'):
                    self.wiz._err("Could not set user picture (no permission to write ~/.face). Setup will continue.")
            except Exception as e:
                print('[DEBUG] Error saving face:', e)
                pass

    def validate(self):
        pw = self.pw_entry.get_text()
        cf = self.cf_entry.get_text()
        if not pw:
            return False, "Password cannot be empty."
        self._check_match()
        if pw != cf:
            return False, ""
        if self._strength(pw) < 60:
            return False, "Password too weak. Use 8+ chars with mixed case, numbers, and symbols."
        self.pw = pw
        return True, ""


class BrowserPage(Gtk.Box):
    BROWSERS = [
        ("Firefox",  "org.mozilla.firefox",  "firefox"),
        ("Brave",    "com.brave.Browser",    "web-browser"),
        ("Zen",      "app.zen_browser.zen",  "web-browser"),
        ("Chromium", "org.chromium.Chromium", "chromium-browser"),
    ]

    def __init__(self, wiz):
        super().__init__(orientation=Gtk.Orientation.VERTICAL, spacing=0)
        self.wiz = wiz
        self._selected = None
        self.set_margin_start(28)
        self.set_margin_end(28)
        self.set_margin_top(8)

        lbl = Gtk.Label(xalign=0.5)
        lbl.set_markup("<span size='xx-large' weight='bold'>Choose your browser</span>")
        self.pack_start(lbl, False, False, 0)
        lbl2 = Gtk.Label(xalign=0.5,
                         label="It will be installed via Flatpak.")
        lbl2.get_style_context().add_class("subtitle")
        self.pack_start(lbl2, False, False, 0)

        self.pack_start(Gtk.Box(), True, True, 0)

        # ponytail: detect already installed flatpaks for green outline
        installed = set()
        try:
            r = subprocess.run(
                ["flatpak", "list", "--app", "--columns=application"],
                capture_output=True, text=True, timeout=5,
            )
            installed = set(r.stdout.strip().splitlines())
        except:
            pass

        first = True
        default_selected = None
        for name, app_id, icon in self.BROWSERS:
            row = Gtk.Box(spacing=10)
            row.get_style_context().add_class("browser-row")
            row.set_margin_top(3)
            row.set_margin_bottom(3)

            is_installed = app_id in installed

            if is_installed:
                # ponytail: green filled dot for already-installed browsers
                dot = Gtk.Label()
                dot.set_markup("<span foreground='#4CAF50' size='large'>●</span>")
                dot.set_valign(Gtk.Align.CENTER)
                dot.set_halign(Gtk.Align.CENTER)
                dot.set_margin_start(6)
                dot.set_size_request(20, -1)
                row.pack_start(dot, False, False, 0)
            else:
                if first:
                    rb = Gtk.RadioButton.new_with_label(None, "")
                    rb.set_active(True)
                    self._selected = (app_id, name)
                    self.group = rb
                    first = False
                else:
                    rb = Gtk.RadioButton.new_with_label_from_widget(self.group, "")

                rb.connect("toggled", lambda r, a=app_id, n=name: (
                    setattr(self, "_selected", (a, n)) if r.get_active() else None,
                    self.wiz._update_buttons() if r.get_active() else None
                ))
                row.pack_start(rb, False, False, 0)

            # ponytail: use flatpak app-id as icon name if available (full icon)
            theme = Gtk.IconTheme.get_default()
            icon_name = app_id if theme.has_icon(app_id) else icon
            img = Gtk.Image.new_from_icon_name(icon_name, Gtk.IconSize.DIALOG)
            lbl = Gtk.Label(label=name, xalign=0)
            lbl.set_markup(f"<b>{name}</b>")

            row.pack_start(img, False, False, 0)
            row.pack_start(lbl, True, True, 0)

            if is_installed:
                self.pack_start(row, False, False, 0)
            else:
                ev = Gtk.EventBox()
                ev.add(row)
                ev.connect("button-press-event", lambda *_, r=rb: (r.set_active(True), True))
                self.pack_start(ev, False, False, 0)

        # fallback if first browser was installed
        if self._selected is None:
            for name, app_id, icon in self.BROWSERS:
                if app_id not in installed:
                    self._selected = (app_id, name)
                    break
        
        self._all_installed = self._selected is None and all(
            app_id in installed for _, app_id, _ in self.BROWSERS
        )

        self.pack_start(Gtk.Box(), True, True, 0)

    def get_selected(self):
        return self._selected

    def all_installed(self):
        return self._all_installed


class SocialPage(Gtk.Box):
    SOCIALS = [
        ("Telegram",  "org.telegram.desktop",    "telegram-desktop"),
        ("Discord",   "com.discordapp.Discord",   "discord"),
        ("Vesktop",   "dev.vencord.Vesktop",      "web-browser"),
        ("Signal",    "org.signal.Signal",          "signal-desktop"),
    ]

    def __init__(self, wiz):
        super().__init__(orientation=Gtk.Orientation.VERTICAL, spacing=0)
        self.wiz = wiz
        self._selected = None
        self.set_margin_start(28)
        self.set_margin_end(28)
        self.set_margin_top(8)

        lbl = Gtk.Label(xalign=0.5)
        lbl.set_markup("<span size='xx-large' weight='bold'>Choose your social apps</span>")
        self.pack_start(lbl, False, False, 0)
        lbl2 = Gtk.Label(xalign=0.5,
                         label="They will be installed via Flatpak.")
        lbl2.get_style_context().add_class("subtitle")
        self.pack_start(lbl2, False, False, 0)

        self.pack_start(Gtk.Box(), True, True, 0)

        installed = set()
        try:
            r = subprocess.run(
                ["flatpak", "list", "--app", "--columns=application"],
                capture_output=True, text=True, timeout=5,
            )
            installed = set(r.stdout.strip().splitlines())
        except:
            pass

        first = True
        for name, app_id, icon in self.SOCIALS:
            row = Gtk.Box(spacing=10)
            row.get_style_context().add_class("browser-row")
            row.set_margin_top(3)
            row.set_margin_bottom(3)

            is_installed = app_id in installed

            if is_installed:
                dot = Gtk.Label()
                dot.set_markup("<span foreground='#4CAF50' size='large'>●</span>")
                dot.set_valign(Gtk.Align.CENTER)
                dot.set_halign(Gtk.Align.CENTER)
                dot.set_margin_start(6)
                dot.set_size_request(20, -1)
                row.pack_start(dot, False, False, 0)
            else:
                if first:
                    rb = Gtk.RadioButton.new_with_label(None, "")
                    rb.set_active(True)
                    self._selected = (app_id, name)
                    self.group = rb
                    first = False
                else:
                    rb = Gtk.RadioButton.new_with_label_from_widget(self.group, "")

                rb.connect("toggled", lambda r, a=app_id, n=name: (
                    setattr(self, "_selected", (a, n)) if r.get_active() else None
                ))
                row.pack_start(rb, False, False, 0)

            theme = Gtk.IconTheme.get_default()
            icon_name = app_id if theme.has_icon(app_id) else icon
            img = Gtk.Image.new_from_icon_name(icon_name, Gtk.IconSize.DIALOG)
            lbl = Gtk.Label(label=name, xalign=0)
            lbl.set_markup(f"<b>{name}</b>")

            row.pack_start(img, False, False, 0)
            row.pack_start(lbl, True, True, 0)

            if is_installed:
                self.pack_start(row, False, False, 0)
            else:
                ev = Gtk.EventBox()
                ev.add(row)
                ev.connect("button-press-event", lambda *_, r=rb: (r.set_active(True), True))
                self.pack_start(ev, False, False, 0)

        if self._selected is None:
            for name, app_id, icon in self.SOCIALS:
                if app_id not in installed:
                    self._selected = (app_id, name)
                    break

        self._all_installed = self._selected is None and all(
            app_id in installed for _, app_id, _ in self.SOCIALS
        )

        self.pack_start(Gtk.Box(), True, True, 0)

    def get_selected(self):
        return self._selected

    def all_installed(self):
        return self._all_installed


class SopsPage(Gtk.Box):
    def __init__(self, wiz):
        super().__init__(orientation=Gtk.Orientation.VERTICAL, spacing=0)
        self.wiz = wiz
        self._age_key = ""
        self._pubkey = ""
        self.set_margin_start(28)
        self.set_margin_end(28)
        self.set_margin_top(8)

        lbl = Gtk.Label(xalign=0.5)
        lbl.set_markup("<span size='xx-large' weight='bold'>Encryption</span>")
        self.pack_start(lbl, False, False, 0)
        desc = Gtk.Label(xalign=0.5)
        desc.set_markup(
            "Set up SOPS with age for encrypting secrets in your NixOS config.\n"
            "Generate a key below or skip if one already exists."
        )
        desc.get_style_context().add_class("subtitle")
        self.pack_start(desc, False, False, 0)

        self.pack_start(Gtk.Box(), True, True, 0)

        self.lock_lbl = Gtk.Label(xalign=0.5)
        self.lock_lbl.set_margin_bottom(8)
        self.pack_start(self.lock_lbl, False, False, 0)

        self.status_lbl = Gtk.Label(xalign=0.5)
        self.pack_start(self.status_lbl, False, False, 0)

        self.gen_btn = Gtk.Button(label="_Generate Age Key", use_underline=True)
        self.gen_btn.set_margin_top(16)
        self.gen_btn.set_halign(Gtk.Align.CENTER)
        self.gen_btn.get_style_context().add_class("suggested-action")
        self.gen_btn.connect("clicked", self._generate)
        self.pack_start(self.gen_btn, False, False, 0)

        self.pack_start(Gtk.Box(), True, True, 0)

        self._check()

    def _check(self):
        key_path = os.path.expanduser("~/.config/sops/age/keys.txt")
        if os.path.isfile(key_path):
            # ponytail: file exists → key is present, disable generate button
            self.gen_btn.set_sensitive(False)
            try:
                with open(key_path) as f:
                    self._age_key = f.read().strip()
                self._pubkey = self._extract_pubkey(self._age_key)
                self.lock_lbl.set_markup(
                    "<span foreground='#4CAF50' size='xx-large'>\U0001f512</span>"
                )
                self.status_lbl.set_markup("<b>Encryption key ready</b>")
            except Exception:
                self._status_missing()
                self.gen_btn.set_sensitive(True)
        else:
            self._status_missing()

    def _status_missing(self):
        self.lock_lbl.set_markup(
            "<span foreground='#e74c3c' size='xx-large'>\U0001f513</span>"
        )
        self.status_lbl.set_markup("<span foreground='#888'>No encryption key</span>")
        self._age_key = ""
        self._pubkey = ""

    def _extract_pubkey(self, age_key):
        for line in age_key.splitlines():
            if line.startswith("# public key: "):
                return line.split("# public key: ")[1]
        return ""

    def _generate(self, *a):
        try:
            r = subprocess.run(
                ["age-keygen"],
                capture_output=True, text=True, timeout=10,
            )
            if r.returncode != 0:
                self.status_lbl.set_markup("<span color='red'>Failed to generate key</span>")
                return
            self._age_key = r.stdout.strip()
            self._pubkey = self._extract_pubkey(self._age_key)
            self.lock_lbl.set_markup(
                "<span foreground='#4CAF50' size='xx-large'>\U0001f512</span>"
            )
            self.status_lbl.set_markup("<b>Key generated</b>")
            self.gen_btn.set_sensitive(False)
        except FileNotFoundError:
            self.status_lbl.set_markup(
                "<span color='red'>age-keygen not found (install age)</span>"
            )

    def get_result(self):
        return self._age_key, self._pubkey


class ConnectionPage(Gtk.Box):
    ICON_NAMES = {
        "mullvad": "mullvad-vpn",
        "ssh": "security-high",
        "gpg": "dialog-password",
        "openpgp": "application-certificate",
        "signify": "security-medium",
        "openai": "ai",
        "anthropic": "ai",
        "gemini": "gemini",
        "openrouter": "network-vpn",
        "git": "git",
        "hostname": "computer",
        "wifi_ssid": "network-wireless",
        "wifi_password": "network-wireless",
        "tailscale": "network-vpn",
    }

    ITEMS = [
        ("mullvad",       "Mullvad",       False, False),
        ("ssh",           "SSH",           False, False),
        ("gpg",           "GPG",           False, False),
        ("openpgp",       "OpenPGP",       False, False),
        ("signify",       "Signify",       False, False),
        ("openai",        "OpenAI",        True,  False),
        ("anthropic",     "Anthropic",     True,  False),
        ("gemini",        "Gemini",        True,  False),
        ("openrouter",    "OpenRouter",    True,  False),
        ("git",           "Git",           False, False),
        ("hostname",      "Hostname",      False, False),
        ("wifi_ssid",     "WiFi SSID",     False, False),
        ("wifi_password", "WiFi pass",     True,  False),
        ("tailscale",     "Tailscale",     False, True),
    ]

    def __init__(self, wiz):
        super().__init__(orientation=Gtk.Orientation.VERTICAL, spacing=0)
        self.wiz = wiz
        self.set_margin_start(28)
        self.set_margin_end(28)
        self.set_margin_top(8)

        lbl = Gtk.Label(xalign=0.5)
        lbl.set_markup("<span size='xx-large' weight='bold'>Connection</span>")
        self.pack_start(lbl, False, False, 0)
        desc = Gtk.Label(xalign=0.5)
        desc.set_markup(
            "VPN, keys, API tokens, git config, and network. All values are optional."
        )
        desc.get_style_context().add_class("subtitle")
        self.pack_start(desc, False, False, 0)

        sw = Gtk.ScrolledWindow()
        sw.set_policy(Gtk.PolicyType.NEVER, Gtk.PolicyType.AUTOMATIC)
        sw.set_min_content_height(300)
        self.pack_start(sw, True, True, 0)

        outer = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=0)
        outer.set_margin_top(10)
        sw.add(outer)

        grid = Gtk.Grid(row_spacing=8, column_spacing=8)
        grid.set_halign(Gtk.Align.CENTER)
        outer.pack_start(grid, False, False, 0)
        outer.pack_start(Gtk.Box(), True, True, 0)

        self.values = {}
        self.tiles = {}
        self.buttons = {}
        self.status_lbls = {}
        self.checkmarks = {}
        COLS = 4

        for i, (key, label, secret, toggle) in enumerate(self.ITEMS):
            r, c = divmod(i, COLS)
            tile = self._make_tile(key, label, toggle)
            grid.attach(tile, c, r, 1, 1)
            self.tiles[key] = tile

    def _make_tile(self, key, label, is_toggle):
        btn = Gtk.Button()
        btn.get_style_context().add_class("tile")
        btn.set_size_request(126, 100)
        btn.set_relief(Gtk.ReliefStyle.NONE)

        vbox = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=4)
        vbox.set_valign(Gtk.Align.CENTER)
        vbox.set_vexpand(True)

        icon_name = self.ICON_NAMES.get(key, "emblem-system")
        icon = Gtk.Image.new_from_icon_name(icon_name, Gtk.IconSize.DIALOG)
        icon.set_pixel_size(42)
        vbox.pack_start(icon, False, False, 0)

        lbl = Gtk.Label(label=label)
        vbox.pack_start(lbl, False, False, 0)

        status_lbl = Gtk.Label()
        status_lbl.set_markup("<span size='small' color='#666'></span>")
        vbox.pack_start(status_lbl, False, False, 0)
        self.status_lbls[key] = status_lbl

        btn.add(vbox)
        self.buttons[key] = btn

        overlay = Gtk.Overlay()
        overlay.add(btn)

        check = Gtk.Label()
        check.set_markup("<span foreground='#2ecc71' size='x-large'>\u2713</span>")
        check.set_valign(Gtk.Align.START)
        check.set_halign(Gtk.Align.END)
        check.set_margin_top(3)
        check.set_margin_end(3)
        check.set_no_show_all(True)
        overlay.add_overlay(check)
        self.checkmarks[key] = check

        btn.connect("clicked", lambda b, k=key: self._on_tile_click(k))
        return overlay

    def _on_tile_click(self, key):
        if key == "tailscale":
            self.values["tailscale"] = not self.values.get("tailscale", False)
            self._update_tile(key)
            return
        if key == "git":
            self._edit_git()
            return
        item = next((x for x in self.ITEMS if x[0] == key), None)
        if not item:
            return
        _, label, secret, _ = item
        self._edit_dialog(key, label, secret)

    def _update_tile(self, key):
        ctx = self.buttons[key].get_style_context()
        done = False
        if key == "tailscale":
            if self.values.get("tailscale"):
                ctx.add_class("tile-on")
                self._set_tile_status(key, "On")
                self.checkmarks[key].show()
            else:
                ctx.remove_class("tile-on")
                self._set_tile_status(key, "Off")
                self.checkmarks[key].hide()
            return
        if key == "git":
            name = self.values.get("git_user", "")
            email = self.values.get("git_email", "")
            done = bool(name and email)
            if done:
                self._set_tile_status(key, name[:12] + ("\u2026" if len(name) > 12 else ""))
            else:
                self._set_tile_status(key, name or "")
        else:
            val = self.values.get(key)
            done = bool(val and str(val).strip())
            if done:
                s = str(val)
                self._set_tile_status(key, s[:12] + ("\u2026" if len(s) > 12 else ""))
            else:
                self._set_tile_status(key, "")
        if done:
            ctx.add_class("tile-done")
            self.checkmarks[key].show()
        else:
            ctx.remove_class("tile-done")
            self.checkmarks[key].hide()

    def _set_tile_status(self, key, text):
        self.status_lbls[key].set_markup(f"<span size='small' color='#888'>{text}</span>")

    def _mk_entry(self, placeholder, secret, text=""):
        e = Gtk.Entry()
        e.set_placeholder_text(placeholder)
        e.set_visibility(not secret)
        if text:
            e.set_text(text)
        if secret:
            e.set_visibility(False)
            e.set_icon_from_icon_name(Gtk.EntryIconPosition.SECONDARY,
                                      "view-reveal-symbolic")
            e.connect("icon-press", self._toggle_visibility)
        return e

    def _edit_git(self):
        d = Gtk.Dialog(title="Git", transient_for=self.wiz, modal=True)
        d.set_default_size(380, -1)
        d.set_resizable(False)

        c = d.get_content_area()
        c.set_margin_start(20)
        c.set_margin_end(20)
        c.set_margin_top(16)
        c.set_margin_bottom(8)
        c.set_spacing(6)

        hdr = Gtk.Label(xalign=0)
        hdr.set_markup("<b><span size='large'>Git Configuration</span></b>")
        c.pack_start(hdr, False, False, 0)

        name_e = self._mk_entry("Your Name", False, self.values.get("git_user", ""))
        email_e = self._mk_entry("your@email.com", False, self.values.get("git_email", ""))

        c.pack_start(name_e, False, False, 0)
        c.pack_start(email_e, False, False, 0)

        err = Gtk.Label(xalign=0)
        err.set_markup("<span color='#e74c3c' size='small'></span>")
        err.set_no_show_all(True)
        c.pack_start(err, False, False, 0)

        d.add_button("_Cancel", Gtk.ResponseType.CANCEL)
        d.add_button("_Save", Gtk.ResponseType.OK)

        d.show_all()
        response = d.run()
        while response == Gtk.ResponseType.OK:
            name = name_e.get_text().strip()
            email = email_e.get_text().strip()
            if not name:
                err.set_markup("<span color='#e74c3c' size='small'>Name is required</span>")
                err.show()
            elif email and ("@" not in email or "." not in email.split("@")[-1]):
                err.set_markup("<span color='#e74c3c' size='small'>Invalid email address</span>")
                err.show()
            else:
                if name:
                    self.values["git_user"] = name
                else:
                    self.values.pop("git_user", None)
                if email:
                    self.values["git_email"] = email
                else:
                    self.values.pop("git_email", None)
                self._update_tile("git")
                break
            d.show()
            response = d.run()
        d.destroy()

    def _edit_dialog(self, key, label, secret):
        d = Gtk.Dialog(title=label, transient_for=self.wiz, modal=True)
        d.set_default_size(380, -1)
        d.set_resizable(False)

        c = d.get_content_area()
        c.set_margin_start(20)
        c.set_margin_end(20)
        c.set_margin_top(16)
        c.set_margin_bottom(8)
        c.set_spacing(6)

        hdr = Gtk.Label(xalign=0)
        hdr.set_markup(f"<b><span size='large'>{label}</span></b>")
        c.pack_start(hdr, False, False, 0)

        entry = self._mk_entry(f"Enter {label}", secret, str(self.values.get(key, "")))
        c.pack_start(entry, False, False, 0)

        err = Gtk.Label(xalign=0)
        err.set_markup("<span color='#e74c3c' size='small'></span>")
        err.set_no_show_all(True)
        c.pack_start(err, False, False, 0)

        api_keys = ("openai", "anthropic", "gemini", "openrouter")
        verify_btn = None
        verify_lbl = None
        if key in api_keys:
            verify_lbl = Gtk.Label(xalign=0)
            verify_lbl.set_no_show_all(True)
            c.pack_start(verify_lbl, False, False, 0)
            verify_btn = Gtk.Button(label="_Verify", use_underline=True)
            verify_btn.set_halign(Gtk.Align.START)
            c.pack_start(verify_btn, False, False, 0)

        d.add_button("_Cancel", Gtk.ResponseType.CANCEL)
        d.add_button("_Save", Gtk.ResponseType.OK)

        if verify_btn:

            def on_verify(b):
                val = entry.get_text().strip()
                if not val:
                    return
                verify_btn.set_sensitive(False)
                verify_btn.set_label("Verifying\u2026")

                def do_verify():
                    ok, msg = self._verify_api_key(key, val)
                    GLib.idle_add(lambda: _show_result(ok, msg))
                    GLib.idle_add(lambda: verify_btn.set_sensitive(True))
                    GLib.idle_add(lambda: verify_btn.set_label("_Verify"))

                def _show_result(ok, msg):
                    if ok:
                        verify_lbl.set_markup(
                            f"<span foreground='#2ecc71'>\u2713 {msg}</span>")
                    else:
                        verify_lbl.set_markup(
                            f"<span foreground='#e74c3c'>\u2717 {msg}</span>")
                    verify_lbl.show()

                t = threading.Thread(target=do_verify, daemon=True)
                t.start()

            verify_btn.connect("clicked", on_verify)

        d.show_all()
        response = d.run()
        while response == Gtk.ResponseType.OK:
            val = entry.get_text().strip()
            if not val:
                self.values.pop(key, None)
                self._update_tile(key)
                break
            ok, msg = self._validate(key, val)
            if ok:
                self.values[key] = val
                self._update_tile(key)
                break
            err.set_markup(f"<span color='#e74c3c' size='small'>{msg}</span>")
            err.show()
            d.show()
            response = d.run()
        d.destroy()

    def _toggle_visibility(self, entry, pos, *a):
        v = not entry.get_visibility()
        entry.set_visibility(v)
        entry.set_icon_from_icon_name(Gtk.EntryIconPosition.SECONDARY,
                                      "view-conceal-symbolic" if v else "view-reveal-symbolic")

    def _validate(self, key, val):
        if key == "mullvad":
            if not val.isdigit():
                return False, "Must be a numeric account number"
        elif key == "ssh":
            if not val.startswith(("ssh-ed25519 ", "ssh-rsa ", "ssh-ecdsa ", "ssh-ed448 ", "ssh-dss ")):
                return False, "Must start with ssh-ed25519, ssh-rsa, etc."
        elif key == "gpg":
            if not re.match(r'^[0-9A-Fa-f]{16,40}$', val):
                return False, "Must be a 16\u201340 char hex fingerprint"
        elif key == "openpgp":
            if not re.match(r'^[0-9A-Fa-f]{16,40}$', val):
                return False, "Must be a 16\u201340 char hex fingerprint"
        elif key == "signify":
            if not val.startswith("RWT"):
                return False, "Must start with RWT..."
        elif key == "openai":
            if not val.startswith("sk-"):
                return False, "Must start with sk-..."
        elif key == "anthropic":
            if not val.startswith("sk-ant-"):
                return False, "Must start with sk-ant-..."
        elif key == "hostname":
            if not re.match(r'^[a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?$', val):
                return False, "Invalid hostname format"
        return True, ""

    def _verify_api_key(self, key, val):
        import urllib.request
        import urllib.error
        if key == "openai":
            req = urllib.request.Request(
                "https://api.openai.com/v1/models",
                headers={"Authorization": f"Bearer {val}"},
                method="HEAD")
            try:
                urllib.request.urlopen(req, timeout=8)
                return True, "Key valid"
            except urllib.error.HTTPError as e:
                return False, f"HTTP {e.code}: {e.reason}"
            except Exception as e:
                return False, f"Error: {e}"
        elif key == "anthropic":
            req = urllib.request.Request(
                "https://api.anthropic.com/v1/messages",
                headers={"x-api-key": val, "anthropic-version": "2023-06-01",
                         "content-type": "application/json"},
                data=b'{}',
                method="POST")
            try:
                urllib.request.urlopen(req, timeout=8)
                return True, "Key valid"
            except urllib.error.HTTPError as e:
                if e.code in (401, 403):
                    return False, "Key invalid"
                return True, "Auth accepted"
            except Exception as e:
                return False, f"Error: {e}"
        elif key == "gemini":
            req = urllib.request.Request(
                f"https://generativelanguage.googleapis.com/v1/models?key={val}",
                method="HEAD")
            try:
                urllib.request.urlopen(req, timeout=8)
                return True, "Key valid"
            except urllib.error.HTTPError as e:
                return False, f"HTTP {e.code}: {e.reason}"
            except Exception as e:
                return False, f"Error: {e}"
        elif key == "openrouter":
            req = urllib.request.Request(
                "https://openrouter.ai/api/v1/auth/key",
                headers={"Authorization": f"Bearer {val}"})
            try:
                urllib.request.urlopen(req, timeout=8)
                return True, "Key valid"
            except urllib.error.HTTPError as e:
                return False, f"HTTP {e.code}: {e.reason}"
            except Exception as e:
                return False, f"Error: {e}"
        return True, ""

    def get_result(self):
        return dict(self.values)

    def set_initial_values(self, data):
        if not data:
            return
        for k, v in data.items():
            if v:
                self.values[k] = v
        for k in list(self.tiles):
            self._update_tile(k)


class GitHubPage(Gtk.Box):
    def __init__(self, wiz):
        super().__init__(orientation=Gtk.Orientation.VERTICAL, spacing=0)
        self.wiz = wiz
        self.set_margin_start(28)
        self.set_margin_end(28)
        self.set_margin_top(8)

        lbl = Gtk.Label(xalign=0.5)
        lbl.set_markup("<span size='xx-large' weight='bold'>GitHub Backup</span>")
        self.pack_start(lbl, False, False, 0)
        desc = Gtk.Label(xalign=0.5)
        desc.set_markup(
            "Enter the repository for your NixOS config.\n"
            "You will set up access on the next page."
        )
        desc.get_style_context().add_class("subtitle")
        self.pack_start(desc, False, False, 0)

        self.pack_start(Gtk.Box(), True, True, 0)

        gf = Gtk.Grid(row_spacing=10, column_spacing=10, margin_top=8)
        gf.set_halign(Gtk.Align.CENTER)

        theme = Gtk.IconTheme.get_default()
        icon_name = "git" if theme.has_icon("git") else "emblem-vcs"
        git_icon = Gtk.Image.new_from_icon_name(icon_name, Gtk.IconSize.DIALOG)
        git_icon.set_pixel_size(24)

        self.repo_entry = Gtk.Entry()
        self.repo_entry.set_placeholder_text("username/mujō")
        self.repo_entry.set_width_chars(30)

        gf.attach(git_icon, 0, 0, 1, 1)
        gf.attach(self.repo_entry, 1, 0, 1, 1)

        self.pack_start(gf, False, False, 0)

        self.repo_error_lbl = Gtk.Label(xalign=0.5)
        self.repo_error_lbl.set_margin_top(4)
        self.repo_error_lbl.set_markup("<span color='#e74c3c' size='small'>Repository not found</span>")
        self.repo_error_lbl.set_no_show_all(True)
        self.pack_start(self.repo_error_lbl, False, False, 0)

        self.pack_start(Gtk.Box(), True, True, 0)

    def _normalize_url(self, raw):
        raw = raw.strip()
        if raw.endswith(".git"):
            raw = raw[:-4]
        if raw.startswith("https://github.com/") or raw.startswith("git@github.com:"):
            return f"{raw}.git"
        return f"https://github.com/{raw}.git"

    def validate(self):
        raw = self.repo_entry.get_text().strip()
        ctx = self.repo_entry.get_style_context()
        if not raw:
            self.repo_error_lbl.set_markup("<span color='#e74c3c' size='small'>Enter a repository</span>")
            self.repo_error_lbl.show()
            ctx.add_class("entry-error")
            return False
        url = self._normalize_url(raw)
        r = subprocess.run(
            ["git", "ls-remote", url, "HEAD"],
            capture_output=True, timeout=10,
        )
        if r.returncode != 0:
            ctx.add_class("entry-error")
            self.repo_error_lbl.set_markup(
                "<span color='#e74c3c' size='small'>Repository not found or not accessible</span>"
            )
            self.repo_error_lbl.show()
            return False
        ctx.remove_class("entry-error")
        self.repo_error_lbl.hide()
        return True

    def get_result(self):
        return self.repo_entry.get_text().strip()

    def set_initial_values(self, data):
        if data and "repo" in data:
            self.repo_entry.set_text(data["repo"])


class TokenPage(Gtk.Box):
    def __init__(self, wiz):
        super().__init__(orientation=Gtk.Orientation.VERTICAL, spacing=0)
        self.wiz = wiz
        self.set_margin_start(28)
        self.set_margin_end(28)
        self.set_margin_top(8)

        lbl = Gtk.Label(xalign=0.5)
        lbl.set_markup("<span size='xx-large' weight='bold'>Access Token</span>")
        self.pack_start(lbl, False, False, 0)
        desc = Gtk.Label(xalign=0.5)
        desc.set_markup(
            "Create a <b>classic token</b> with <tt>repo</tt> scope on GitHub,\n"
            "then paste it below."
        )
        desc.get_style_context().add_class("subtitle")
        self.pack_start(desc, False, False, 0)

        self.pack_start(Gtk.Box(), True, True, 0)

        gf = Gtk.Grid(row_spacing=10, column_spacing=10, margin_top=8)
        gf.set_halign(Gtk.Align.CENTER)

        theme = Gtk.IconTheme.get_default()
        icon_name = "git" if theme.has_icon("git") else "emblem-vcs"
        key_icon = Gtk.Image.new_from_icon_name(icon_name, Gtk.IconSize.DIALOG)
        key_icon.set_pixel_size(24)

        self.token_entry = Gtk.Entry()
        self.token_entry.set_placeholder_text("ghp_xxxxxxxxxxxxxxxxxxxx")
        self.token_entry.set_width_chars(30)
        self.token_entry.set_visibility(False)

        self.token_btn = Gtk.Button(label="_Get Token", use_underline=True)
        self.token_btn.set_halign(Gtk.Align.CENTER)
        self.token_btn.connect("clicked", lambda *a: self._open_url())

        gf.attach(key_icon, 0, 0, 1, 1)
        gf.attach(self.token_entry, 1, 0, 1, 1)
        gf.attach(self.token_btn, 0, 1, 2, 1)

        self.pack_start(gf, False, False, 0)

        self.pack_start(Gtk.Box(), True, True, 0)

    def _open_url(self):
        subprocess.Popen(["xdg-open", "https://github.com/settings/tokens"])

    def get_result(self):
        return self.token_entry.get_text().strip()

    def set_initial_values(self, data):
        if data and "token" in data:
            self.token_entry.set_text(data["token"])


class PersistPage(Gtk.Box):
    def __init__(self, wiz):
        super().__init__(orientation=Gtk.Orientation.VERTICAL, spacing=0)
        self.wiz = wiz
        self.set_margin_start(28)
        self.set_margin_end(28)
        self.set_margin_top(8)

        lbl = Gtk.Label(xalign=0.5)
        lbl.set_markup("<span size='xx-large' weight='bold'>Persistent Storage</span>")
        self.pack_start(lbl, False, False, 0)
        desc = Gtk.Label(xalign=0.5)
        desc.set_markup(
            "Back up persistent system data (home, state, secrets).\n"
            "Configure a cron job to keep your data safe."
        )
        desc.get_style_context().add_class("subtitle")
        self.pack_start(desc, False, False, 0)

        self.pack_start(Gtk.Box(), True, True, 0)

        self.check = Gtk.CheckButton(label="_Enable persistent backup", use_underline=True)
        self.check.set_margin_bottom(12)
        self.check.set_halign(Gtk.Align.CENTER)
        self.check.connect("toggled", self._on_toggle)
        self.pack_start(self.check, False, False, 0)

        gf = Gtk.Grid(row_spacing=8, column_spacing=10)
        gf.set_halign(Gtk.Align.CENTER)

        dest_lbl = Gtk.Label(label="Destination", xalign=1)
        self.dest_entry = Gtk.Entry()
        self.dest_entry.set_placeholder_text("/run/media/backup or user@host:path")
        self.dest_entry.set_width_chars(34)
        self.dest_entry.set_sensitive(False)

        path_lbl = Gtk.Label(label="Source path", xalign=1)
        self.path_entry = Gtk.Entry()
        self.path_entry.set_text("/persist")
        self.path_entry.set_width_chars(34)
        self.path_entry.set_sensitive(False)

        gf.attach(path_lbl, 0, 0, 1, 1)
        gf.attach(self.path_entry, 1, 0, 1, 1)
        gf.attach(dest_lbl, 0, 1, 1, 1)
        gf.attach(self.dest_entry, 1, 1, 1, 1)

        self.grid = gf
        gf.set_sensitive(False)
        self.pack_start(gf, False, False, 0)

        self.pack_start(Gtk.Box(), True, True, 0)

    def _on_toggle(self, *a):
        active = self.check.get_active()
        self.grid.set_sensitive(active)

    def get_result(self):
        if self.check.get_active():
            return {
                "enabled": True,
                "source": self.path_entry.get_text().strip() or "/persist",
                "destination": self.dest_entry.get_text().strip(),
            }
        return {"enabled": False}

    def set_initial_values(self, data):
        if data and data.get("enabled"):
            self.check.set_active(True)
            if "source" in data:
                self.path_entry.set_text(data["source"])
            if "destination" in data:
                self.dest_entry.set_text(data["destination"])


class ApplyPage(Gtk.Box):
    def __init__(self, wiz):
        super().__init__(orientation=Gtk.Orientation.VERTICAL, spacing=0)
        self.set_margin_start(40)
        self.set_margin_end(40)
        self.set_margin_top(40)

        self.spinner = Gtk.Spinner()
        self.spinner.set_size_request(48, 48)
        self.spinner.start()
        self.pack_start(self.spinner, False, False, 0)

        self.pack_start(Gtk.Box(), True, True, 4)

        self.status_lbl = Gtk.Label(label="Starting\u2026", xalign=0)
        self.status_lbl.get_style_context().add_class("status-text")
        self.pack_start(self.status_lbl, False, False, 0)

        self.pack_start(Gtk.Box(), True, True, 0)

    def update(self, text, failed=False):
        GLib.idle_add(self._update, text, failed)

    def _update(self, text, failed):
        if failed:
            self.status_lbl.set_markup(f"<span color='red'>{text}</span>")
        else:
            self.status_lbl.set_markup(f"<span color='green'>\u2713</span>  {text}")
        return False


class DonePage(Gtk.Box):
    def __init__(self, wiz):
        super().__init__(orientation=Gtk.Orientation.VERTICAL, spacing=0)
        self.wiz = wiz
        self.set_margin_start(40)
        self.set_margin_end(40)
        self.set_margin_top(40)

        self.pack_start(Gtk.Box(), True, True, 0)

        img = Gtk.Image.new_from_icon_name("emblem-default", Gtk.IconSize.DIALOG)
        img.set_pixel_size(64)
        self.pack_start(img, False, False, 0)

        self.title_lbl = Gtk.Label(xalign=0.5)
        self.title_lbl.set_markup("<span size='xx-large' weight='bold'>Setup complete!</span>")
        self.pack_start(self.title_lbl, False, False, 0)

        self.detail_lbl = Gtk.Label(xalign=0.5)
        self.detail_lbl.get_style_context().add_class("subtitle")
        self.pack_start(self.detail_lbl, False, False, 0)

        self.pack_start(Gtk.Box(), True, True, 0)

    def set_result(self, label):
        txt = f"Password set and {label} installed." if label != "nothing" else "Password set. Install skipped."
        self.detail_lbl.set_text(txt)


if __name__ == "__main__":
    flag = os.path.join(os.environ.get("XDG_CACHE_HOME",
                                       os.path.expanduser("~/.cache")),
                        "niri-setup-done")
    if len(sys.argv) > 1 and sys.argv[1] == "--first-run" and os.path.isfile(flag):
        sys.exit(0)

    w = SetupWizard()
    w.run()
