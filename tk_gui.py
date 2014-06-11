def gui_mainloop(q_frames, q_control, e_frame_captured, e_from_gui):
    import Tkinter as tk
    from PIL import Image, ImageTk

    class TkGui(tk.Tk):
        def __init__(self, q_frames, q_control, e_frame_captured, e_from_gui):
            tk.Tk.__init__(self, None)

            self.parent = None
            self.title("Behave!")
            self.q_frames = q_frames
            self.q_control = q_control
            self.e_frame_captured = e_frame_captured
            self.e_from_gui = e_from_gui

            self.frame = tk.Frame(self)
            self.frame.grid(row=1, column=1)

            self.start_web = tk.Button(self.frame, text='Start Camera', width=25,
                                      command=self.start_camera)
            self.start_web.grid(row=0, column=1, sticky=tk.N)

            self.start_web = tk.Button(self.frame, text='Show/Hide Camera', width=25,
                                      command=self.show_hide_camera)
            self.start_web.grid(row=1, column=1, sticky=tk.N)

            self.stop_web = tk.Button(self.frame, text='Stop Camera', width=25,
                                      command=self.stop_camera)
            self.stop_web.grid(row=2, column=1, sticky=tk.N)

            self.quit = tk.Button(self.frame, text='Quit', width=25, command=self.destroy)
            self.quit.grid(row=3, column=1, sticky=tk.N)

            canvas_width = 810 #700 #650 
            canvas_height = 610 #490 #610
            self.canvas = tk.Canvas(self, 
                       width=canvas_width, 
                       height=canvas_height)
            self._margin = 10
            self.canvas.webcam = self.canvas.create_image(self._margin, self._margin,
                                                          anchor=tk.NW, image=None)
            self.canvas.face = self.canvas.create_oval(0, 0, 0, 0,
                                                outline="blue", width=1, dash=(4, 4))
            self.canvas.pos = self.canvas.create_text(0,0,
                                          fill="white",font="Times 18 italic",text="")
            self.canvas.grid(row=0, column=0, rowspan=5, sticky=tk.NW)

        def stop_camera(self):
            #TODO: disable buttom after click, check if it created ok.
            self.q_control.put('stop')
            self.e_from_gui.set()

        def start_camera(self):
            #TODO: disable buttom after click, check if it created ok.
            self.q_control.put('start')
            self.e_from_gui.set()

        def show_hide_camera(self):
            #TODO: disable buttom after click, check if it created ok.
            self.q_control.put('show_hide_camera')
            self.e_from_gui.set()

        def put_img_in_canvas(self, img):
            img = Image.fromarray(img)
            imgtk = ImageTk.PhotoImage(image=img)
            self.canvas.imgtk = imgtk
            self.canvas.itemconfig(self.canvas.webcam, image=self.canvas.imgtk)

        def draw_face_in_canvas(self, face):
            #face>>(x,y,w,h)
            x, y, w, h = face
            self.canvas.coords(self.canvas.face,
                              x + self._margin, y - 35 + self._margin,
                              x + w + self._margin, y + 10 + h + self._margin)
            self.canvas.coords(self.canvas.pos, x, y)
            self.canvas.itemconfig(self.canvas.pos, text='x=%s y=%s' % (x, y))
            
        def update_frame(self):
            #e_frame_captured.wait()

            if not self.q_frames.empty():
                img, face = self.q_frames.get()
                if img is not None:
                    self.put_img_in_canvas(img)
                if face is not None:
                    self.draw_face_in_canvas(face)
            
            self.canvas.after(50, self.update_frame)

    print 'Tkinter is starting'
    gui = TkGui(q_frames, q_control, e_frame_captured, e_from_gui)
    gui.update_frame()
    gui.mainloop()

    # tells master process that gui is quitting:
    q_control.put('quit')
    e_from_gui.set()

    print 'Tkinter process is stopping...'
