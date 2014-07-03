import Tkinter as tk
from PIL import Image, ImageTk

import enforcers
from utils import say_warning

class TkGui(tk.Tk):
    def __init__(self, q_frames, q_control):
        tk.Tk.__init__(self, None)

        self.parent = None
        self.title("Behave!")

        self.q_frames = q_frames
        self.q_control = q_control

        #self.w = tk.Toplevel(self, bg='blue')
        self.f_main = tk.Frame(self, background='snow3')
        self.f_main.grid()

        self.create_control()
        self.create_canvas()

        self.face_enforcer = enforcers.EnforceFaceLimits(say_warning)
        self._auto_num_faces = 5 #TODO: gui configurable
        self._auto_tilt = 10
        self._auto_faces = list()
        self._state = 'enforce'

    def show_hide_camera(self):
        #TODO: disable buttom after click, check if it created ok.
        self.q_control.put('show_hide_camera')

    def auto_adjust(self):
        self._state = 'auto_adjust'

    def create_control(self):

        self.f_control = tk.Frame(self.f_main)
        self.f_control.grid(row=0, column=0, sticky=tk.N)

        self.b_show_hide = tk.Button(self.f_control, text='Toggle show/hide camera', width=20,
                                      command=self.show_hide_camera, font='Helvetica 13')
        self.b_show_hide.grid()

        self.b_auto_adjust = tk.Button(self.f_control, text='Auto adjust', width=20,
                                      command=self.auto_adjust, font='Helvetica 13', 
                                      fg='grey')
        self.b_auto_adjust.grid()

        self.b_quit = tk.Button(self.f_control, text='Quit', width=20,
                                command=self.destroy, font='Helvetica 13')
        self.b_quit.grid()

    def create_canvas(self):
        canvas_w = 200
        canvas_h = 150
        n_lines = 40
        self.canvas = tk.Canvas(self.f_main, width=canvas_w, height=canvas_h,
                                background="snow2")
        self._margin = 1
        self.canvas.webcam = self.canvas.create_image(self._margin, self._margin,
                                                      anchor=tk.NW, image=None)
        self.canvas.face = self.canvas.create_oval(0, 0, 0, 0,
                                            outline="SpringGreen2", width=1, dash=(4, 4))
        self.canvas.pos = self.canvas.create_text(0,0,
                                      fill="white",font="Helvetica 13",text="")
        self.canvas.msg = self.canvas.create_text(5, 5,
                                      fill="white",font="Helvetica 13",text="", anchor=tk.NW)
        self.canvas.select_line = self.canvas.create_line(0, 0, 0, 0, fill='red', width=1, dash=(3,3))
        self.canvas.limit_line = self.canvas.create_line(0, 0, 0, 0, fill='red', width=2)
        for l in range(n_lines):
            obj = self.canvas.create_line(0,0,0,0, fill='red2', width=1, dash=(3,3))
            setattr(self.canvas, 'line' + str(l), obj )

        def motion(event):
            self.canvas.coords(self.canvas.select_line, 0, event.y, canvas_w, event.y)
            
        def left_click(event):
            self.draw_y_limit(event.y)
            self.face_enforcer.set_y_limit_low(y_limit_low=event.y)

        self.canvas.bind('<Motion>', motion)
        self.canvas.bind('<Button-1>', left_click)

        self.canvas.grid(row=1, column=0, rowspan=5)

    def draw_y_limit(self, y):
        #FIXME:
        canvas_w = 200
        n_lines = 40

        self.canvas.coords(self.canvas.limit_line, 0, y, canvas_w, y)
        pos_x = 0 
        for l in range(n_lines):
            pos_x += canvas_w / float(n_lines)
            obj = getattr(self.canvas, 'line' + str(l))
            self.canvas.coords(obj, pos_x, 150, pos_x, y)

    def draw_img_in_canvas(self, img):
        img = Image.fromarray(img)
        imgtk = ImageTk.PhotoImage(image=img)
        self.canvas.imgtk = imgtk
        self.canvas.itemconfig(self.canvas.webcam, image=self.canvas.imgtk)

    def draw_msg_in_canvas(self, msg):
        if msg is None:
            msg = ''
        self.canvas.itemconfig(self.canvas.msg, text=msg)
        
    def draw_face_in_canvas(self, face):
        x, y, w, h = face
        self.canvas.coords(self.canvas.face,
                          x + self._margin, y + self._margin,
                          x + w + self._margin, y + h + self._margin)

        if self.face_enforcer.is_face_ok(face):
            color = 'green'
            width = 1
        else:
            color = 'red'
            width = 2
        self.canvas.itemconfig(self.canvas.face, outline=color, width=width)

        #self.canvas.coords(self.canvas.pos, 2 * x, y + h / 2.0)
        #self.canvas.itemconfig(self.canvas.pos, text='x=%s y=%s' % (x, y))

    def handle_enforce(self, face): 
        action_needed = None
        msg = None
        
        if self.face_enforcer.is_face_ok(face):
            action_needed, msg = self.face_enforcer.relax()
        else:
            action_needed, msg = self.face_enforcer.enforce(face)

        if action_needed:
            action_needed()
            #slight relax in the limit, trying to adjust.TODO:only reduces.
            #self.face_enforcer.adjust_y_limit_low_after_scold()
        if msg:
            return msg

    def handle_auto_adjust(self, face):
        """Fancy protocol, saves N faces, takes average and sets the y limit with a tilt"""
        self._auto_faces.append(face)

        len_faces = len(self._auto_faces)
        msg = ("Auto-adjusting, sit straight! \n %s of %s" % (len_faces, self._auto_num_faces))
        
        if len_faces == self._auto_num_faces:
            y_s = [y + h for x, y, w, h in self._auto_faces]
            h_s = [h for x, y, w, h in self._auto_faces]
            #Very ugly, but needed, float to get the real avg, then truncate to get pixels
            avg_y_s = int(sum(y_s) / len_faces)
            avg_size = int(float(sum(h_s)) / len_faces)

            surplus = int(float(avg_size) / self._auto_tilt)
            y_limit_low = avg_y_s + surplus

            self.face_enforcer.set_y_limit_low(y_limit_low)
            self.draw_y_limit(y_limit_low)

            #leaving the auto adjustment, cleaning up:
            self.face_enforcer.reset_wrongs()
            self.face_enforcer.reset_oks()
            self._auto_faces = list() 
            self._state = 'enforce'

        return msg

    def update_frame(self):
        if not self.q_frames.empty():
            img, face = self.q_frames.get()
            if face is not None:
                self.draw_face_in_canvas(face)
                if self._state == 'enforce':
                    msg = self.handle_enforce(face)
                elif self._state == 'auto_adjust':
                    msg = self.handle_auto_adjust(face)
                self.draw_msg_in_canvas(msg)
            if img is not None:
                self.draw_img_in_canvas(img)
        
        self.canvas.after(50, self.update_frame)

