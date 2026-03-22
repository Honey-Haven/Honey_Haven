extends MinigameBase  # PUT THIS 

func _on_setup(_data: Dictionary):
    # Your game initilization/setup e.g.:
    print("Minigame started!")

func _process(delta):
    # Your game logic here
    if input_event_happened:
        finish() # PUT THIS TO EXIT
