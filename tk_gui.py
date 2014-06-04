def gui_mainloop(the_q, event):
    import Tkinter as tk
    from PIL import Image, ImageTk

    class TkGui(tk.Tk):
        def __init__(self):
            tk.Tk.__init__(self, None)

            self.parent = None
            self.title("Behave!")

            button = tk.Button(self, text='Stop', width=25, command=self.destroy)
            button.grid(row=1, column=1, sticky=tk.N)

            canvas_width = 900
            canvas_height = 700
            self.canvas = tk.Canvas(self, 
                       width=canvas_width, 
                       height=canvas_height)
            self.canvas.image_on_canvas = self.canvas.create_image(10,10, anchor=tk.NW, image=None)
            self.canvas.grid(row=0, column=0)

        def update_frame(self, img):
            img = Image.fromarray(img)
            imgtk = ImageTk.PhotoImage(image=img)
            self.canvas.imgtk = imgtk
            self.canvas.itemconfig(self.canvas.image_on_canvas, image=self.canvas.imgtk)
            self.update()

    print 'Tkinter is starting'
    gui = TkGui()

    while True:
        #event.wait()
        img = the_q.get()
        gui.update_frame(img)

    print 'Tkinter is stopped'
