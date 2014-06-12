import Tkinter as tk
from PIL import Image, ImageTk

class TkGui(tk.Tk):
    def __init__(self, q_frames, q_control):
        tk.Tk.__init__(self, None)

        self.parent = None
        self.title("Behave!")

        self.q_frames = q_frames
        self.q_control = q_control

        self.create_control()
        self.create_canvas()

    def show_hide_camera(self):
        #TODO: disable buttom after click, check if it created ok.
        self.q_control.put('show_hide_camera')

    def create_control(self):

        self.frame = tk.Frame(self)
        self.frame.grid(row=0, column=1, sticky=tk.N)

        self.show_hide = tk.Button(self.frame, text='Show/Hide Camera', width=25,
                                  command=self.show_hide_camera)
        self.show_hide.grid(row=1, column=1, sticky=tk.N)

        self.quit = tk.Button(self.frame, text='Quit', width=25, command=self.destroy)
        self.quit.grid(row=3, column=1, sticky=tk.N)

    def create_canvas(self):
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
        
    def update_frame(self):
        # q.get is blocking:
        img, face = self.q_frames.get()
        if img is not None:
            self.put_img_in_canvas(img)
        if face is not None:
            self.draw_face_in_canvas(face)
        
        self.canvas.after(50, self.update_frame)

