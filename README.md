# AnimatedRichTextLabel
Godot script to fade in text on RichTextLabel with custom character animations and wait functionality.

## Usage
1) Add script of AnimatedRichTextLabel to your project.
2) In a RichTextLabel's script use "extends AnimatedRichTextLabel" to get the animation capabilities, adjust the export variables to modify text speed etc.
3) Setting the RichTextLabel's text property starts the animation (if the context is the label itself, use self.text instead of text, otherwise _set won't be called, same thing happens to the text initially set in the inspector, use self.text = text in _ready() as workaround if that's a problem).
4) Use [wait t=1.0] to add wait , t = time (float), -1 = infinite wait time.
5) use [speed v=1.0] to set the speed of a text passage to a different value than text_speed, v = speed (float). Speed can be set either as an absolute or relative value depending on the modify_speed_relative setting. Use [/speed] to set the speed back to text_speed.

optional:
add own transition effects for more sophisticated or custom fade-in animations

example:
https://github-production-user-asset-6210df.s3.amazonaws.com/4991495/296614505-262abe3f-e453-4745-8115-3592551eec3f.mp4



