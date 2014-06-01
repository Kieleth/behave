def gui_mainloop(the_q, event):
    import Tkinter as tk
    from PIL import Image, ImageTk

    class TkGui(tk.Tk):
        def __init__(self):
            tk.Tk.__init__(self, None)

            self.parent = None
            self.bind('<Escape>', lambda e: self.quit())

            self.lmain = tk.Label(self)

            self.lmain.pack()

        def update_frame(self, img):
            img = Image.fromarray(img)
            imgtk = ImageTk.PhotoImage(image=img)
            self.lmain.imgtk = imgtk
            self.lmain.configure(image=imgtk)
            self.update()

    print 'Tkinter is starting'
    gui = TkGui()

    while True:
        #event.wait()
        img = the_q.get()
        gui.update_frame(img)

    print 'Tkinter is stopped'
