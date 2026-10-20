'Editing the text of one of a map's messages from another screen (the speech menus of NPCs and event
'triggers). The messages belong to the map, so every NPC and trigger on that map that uses the message
'shows the new text. Saving checks that the map dialogue fits, as before.


sub EditMessageText(map_index as Integer, message_number as Integer)

 'message_number is the number shown in the speech menu ("Message 4" is 4). The screen as it was is put
 ' back afterwards.

 dim backdrop as Any ptr
 dim enter_message as BlueMessageInput

 if map_index < 1 or map_index > total_maps then exit sub
 if message_number < 1 or message_number > maps(map_index).dialogues.Length() then
  InfoBox("This map has no message " + str(message_number) + ".||Press any key", 20, 20)
  exit sub
 end if

 backdrop = ImageCreate(640, 480)
 get (0, 0)-(639, 479), backdrop
 cls
 WriteText(FF4Text("Message " + str(message_number) + " of " + FF4Name(map_names.ItemAt(map_index))), 4, 1, 14)
 WriteText(FF4Text("Everything on this map that uses the message shows the new text."), 4, 2, 15)
 enter_message = BlueMessageInput(4, 4, maps(map_index).dialogues.ItemAt(message_number))
 enter_message.h = 42
 enter_message.UserType()
 maps(map_index).dialogues.Assign(message_number, enter_message.Message())
 put (0, 0), backdrop, pset
 ImageDestroy(backdrop)
 'a draw on the screen itself, so the destroyed image is not left as the drawing target
 pset (0, 0), point(0, 0)

end sub
