sub WarningMessage(s as String)

 dim blank as Any ptr

 'Remember the problem; the save routine lists them all when it finishes.
 if save_problems <> "" then save_problems += "|"
 save_problems += FF4Name(s)
 warning = true
 if defer_warnings then exit sub
 
 blank = ImageCreate((len(s) + 3) * 8, 3 * 8, RGB(0, 0, 0))
 BlueBox(20, 1, len(s), 1)
 WriteText(s, 21, 2)
 WaitForKeyOrClick()
 put (20 * 8, 1 * 8), blank, pset
 ImageDestroy(blank)

end sub
