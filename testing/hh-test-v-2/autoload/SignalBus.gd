extends Node
# ── Script / Story signals ───────────────────────────────────
signal scene_packet_ready(packet: Dictionary)   # Logic → UI
signal script_finished()                         # whole VN script ended
signal choice_selected(choice_index: int)        # UI → Logic

# ── Dialogue signals ─────────────────────────────────────────
signal dialogue_line_started(packet: Dictionary)
signal dialogue_line_finished()
signal typewriter_tick(char_index: int)          # fired each character

# ── Sprite / Actor signals ───────────────────────────────────
signal actor_show(actor_id: String, expression: String, position: String)
signal actor_hide(actor_id: String)
signal actor_move(actor_id: String, position: String, anim: String)
signal actor_expression(actor_id: String, expression: String)
signal actor_animate(actor_id: String, anim: String)   # shake / hop / etc.

# ── UI effect signals ────────────────────────────────────────
signal textbox_effect(effect: String)            # "flash", "shake", "none"
signal background_change(path: String, transition: String)

# ── Audio signals ────────────────────────────────────────────
signal bgm_play(path: String, fade_in: float)
signal bgm_stop(fade_out: float)
signal sfx_play(path: String)

# ── Minigame / scene transition signals ──────────────────────
signal minigame_start(minigame_id: String, data: Dictionary)
signal minigame_end(result: Dictionary)
signal scene_transition_out(transition: String)
signal scene_transition_in(transition: String)

# ── Theme / customization signals ────────────────────────────
signal theme_changed(theme_data: Dictionary)
