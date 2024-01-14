# AnimatedRichTextLabel
Godot script to fade in text on RichTextLabel with custom character animations and wait functionality.

## Usage
1) add both scripts to your project
2) adjust rich_text_effect_writer.gd's path in animated_rich_text_label.gd to point to the correct file
3) on a RichTextLabel's script "extends AnimatedRichTextLabel" to use the animation capabilities, adjust the export variables
4) setting the RichTextLabel's text property starts the animation (if the context is the label itself, use self.text instead of text, otherwise _set won't be called, same thing happens to the text initially set in the inspector, use self.text = text in _ready() as workaround if that's a problem)
5) use [wait t=1.0] to add wait , t = time (float), -1 = infinite wait time

optional:
add own transition effects for more sophisticated or custom fade-in animations

todo:
- add speed tags (for slower, faster text)
- adjusting text speed should adjust 

example:
https://github.com/AwesomeAxolotl/AnimatedRichTextLabel/assets/4991495/391102bf-a75f-425a-b0de-3275edceb13f

