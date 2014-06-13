import Tkinter as tk
from PIL import Image, ImageTk

class TkGui(tk.Tk):
    def __init__(self, q_frames, q_control):
        tk.Tk.__init__(self, None)

        self.parent = None
        self.title("Behave!")

        self.q_frames = q_frames
        self.q_control = q_control

        self.f_main = tk.Frame(self, background='snow3')
        self.f_main.grid()

        self.create_control()
        self.create_canvas()

    def show_hide_camera(self):
        #TODO: disable buttom after click, check if it created ok.
        self.q_control.put('show_hide_camera')

    def auto_adjust(self):
        self.q_control.put('auto_adjust')

    def create_control(self):

        self.f_control = tk.Frame(self.f_main)
        self.f_control.grid(row=0, column=1, sticky=tk.N)

        self.b_show_hide = tk.Button(self.f_control, text='show/hide camera', width=20,
                                      command=self.show_hide_camera)
        self.b_show_hide.grid()

        self.b_auto_adjust = tk.Button(self.f_control, text='auto adjust', width=20,
                                      command=self.auto_adjust)
        self.b_auto_adjust.grid()

        self.b_quit = tk.Button(self.f_control, text='Quit', width=20,
                                command=self.destroy)
        self.b_quit.grid()

    def create_canvas(self):
        self.canvas = tk.Canvas(self.f_main, width=400, height=300, background="snow2")
        self._margin = 1
        self.canvas.webcam = self.canvas.create_image(self._margin, self._margin,
                                                      anchor=tk.NW, image=None)
        self.canvas.face = self.canvas.create_oval(0, 0, 0, 0,
                                            outline="blue", width=1, dash=(4, 4))
        self.canvas.pos = self.canvas.create_text(0,0,
                                      fill="white",font="Helvetica 14",text="")
        self.canvas.grid(row=0, column=0, rowspan=5)

    def put_img_in_canvas(self, img):
        img = Image.fromarray(img)
        imgtk = ImageTk.PhotoImage(image=img)
        self.canvas.imgtk = imgtk
        self.canvas.itemconfig(self.canvas.webcam, image=self.canvas.imgtk)

    def draw_face_in_canvas(self, face):
        x, y, w, h = face
        self.canvas.coords(self.canvas.face,
                          x + self._margin, y + self._margin,
                          x + w + self._margin, y + h + self._margin)
        self.canvas.coords(self.canvas.pos, 2 * x, y + h / 2.0)
        self.canvas.itemconfig(self.canvas.pos, text='x=%s y=%s' % (x, y))
        
    def update_frame(self):
        if not self.q_frames.empty():
            img, face = self.q_frames.get()
            if img is not None:
                self.put_img_in_canvas(img)
            if face is not None:
                self.draw_face_in_canvas(face)
        
        print 'LOOOOOOOOPED'
        self.canvas.after(50, self.update_frame)

