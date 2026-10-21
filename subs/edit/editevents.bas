sub EditEvents()

 dim select_event as BlueMenu
 dim edit_event as EventMenu
 dim preview_menu as BlueMenu
 dim done as Boolean

 select_event.y = 3
 select_event.swap_enabled = true
 select_event.max_rows = 8
 for i as Integer = 1 to total_events
  select_event.AddOption(Pad(event_names.ItemAt(i), 78, false, FF4Text(" ")))
 next

 edit_event = EventMenu(0, select_event.y + select_event.max_rows + 2)

 preview_menu.max_rows = 1
 for i as Integer = 1 to total_maps
  preview_menu.AddOption(FF4Text("Preview as: ") + map_names.ItemAt(i))
 next

 cls
 do until select_event.cancelled

  do
   edit_event.SetTo(select_event.selected)
   preview_menu.ChangeSelected(events(select_event.selected).map_link)
   preview_menu.Display()
   DrawEventHints(false)
   select_event.title = EventRoomTitle("Events")
   'the list's own tools (changed marks, Ctrl-R revert, Ctrl-C / V copy, Ctrl-U used by, Ctrl-Z undo)
   done = ListInput(select_event, "events")
   if not done then
    select case select_event.last_key
     case TAB_KEY
      preview_menu.UserSelect()
      if not preview_menu.cancelled then events(select_event.selected).map_link = preview_menu.selected
     case INSERT_KEY
      if select_event.highlighted > 0 then
       UndoPush("events", select_event.selected)
       events(select_event.selected).script.Remove(events(select_event.selected).script.Length())
       events(select_event.selected).script.Join(events(select_event.highlighted).script)
       if events(select_event.selected).else_script.Length() > 0 then
        events(select_event.selected).else_script.Remove(events(select_event.selected).else_script.Length())
       end if
       events(select_event.selected).else_script.Join(events(select_event.highlighted).else_script)
       select_event.highlighted = 0
      end if
     case 3, 18, 21, 22, 26, 6, 14, 7, F1_KEY, SPACE_KEY
      'list tools and help: nothing else to do
     case else
      edit_event.edit_event.ChangeSelected(1)
      edit_event.edit_else.ChangeSelected(1)
    end select
   end if
  loop until done

  if not select_event.cancelled then
   if select_event.highlighted > 0 then
    'a swap changes two events, so both can be undone
    UndoPush("events", select_event.highlighted)
    UndoPush("events", select_event.selected)
    swap events(select_event.highlighted), events(select_event.selected)
    select_event.highlighted = 0
   else
    preview_menu.Display()
    EventUndoReset()
    edit_event.UserSelect()
    cls
   end if
  end if

 loop

end sub
