1 folder per game, be sure to include the following for VN integration:

extends MinigameBase  # PUT THIS 

func _on_setup(_data: Dictionary):
    # Your game initilization/setup e.g.:
    print("Minigame started!")

func _process(delta):
    # Your game logic here
    if input_event_happened:
        finish() # PUT THIS TO EXIT
