import Tkinter as tk
from PIL import Image, ImageTk

import enforcers
from utils import say_warning

class TkGui(tk.Tk):
    def __init__(self, q_frames, q_control, FPS, verboseprint):
        tk.Tk.__init__(self, None)

        self.parent = None
        self.title("Behave!")

        self.q_frames = q_frames
        self.q_control = q_control

        self._frame_time = int((1.0 / FPS) * 1000)
        self._auto_num_faces = 5 #TODO: gui configurable
        self._auto_tilt = 10
        self._auto_faces = list()
        self._state = 'enforce'

        self.face_enforcer = enforcers.EnforceFaceLimits(say_warning)
        self._print = verboseprint
        
        self.f_main = tk.Frame(self, background='snow3')
        self.f_main.grid()

        self.canvas = self.create_canvas()
        self.canvas.grid(row=1, column=0)

        self.f_control = self.create_controls_frame()
        self.f_control.grid(row=0, column=0, sticky=tk.N)

    def set_state(self, state):
        self._state = state

    def get_state(self):
        return self._state

    def create_canvas(self):
        _canvas_w = 200
        _canvas_h = 150
        _margin = 1
        canvas = WebCanvas(self.f_main, _canvas_w, _canvas_h, "snow2", _margin)

        #mouse-capturing events
        def mouse_over_webcam(event):
            canvas.coords(self.canvas.select_line, 0, event.y, self.canvas.width, event.y)

        def left_click_on_webcam(event):
            canvas.draw_y_limit(event.y)
            self.face_enforcer.set_y_limit_low(y_limit_low=event.y)

        def mouse_leaves(event):
            canvas.coords(canvas.select_line, 0, 0, 0, 0)

        canvas.bind('<Motion>', mouse_over_webcam)
        canvas.bind('<Button-1>', left_click_on_webcam)
        canvas.bind('<Leave>', mouse_leaves)

        return canvas

    def create_controls_frame(self):
        # Hacky!!! tightly coupled!
        root = self
        f_main = self.f_main
        f_control = ControlsFrame(root, f_main)

        return f_control

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
            self.canvas.draw_y_limit(y_limit_low)

            #leaving the auto adjustment, cleaning up:
            self.face_enforcer.reset_wrongs()
            self.face_enforcer.reset_oks()
            self._auto_faces = list() 
            self.set_state('enforce')

        return msg

    def draw_face_in_canvas(self, face):
        self._print('discovered a face')
        if self.face_enforcer.is_face_ok(face):
            color = 'green'
            width = 1
        else:
            color = 'red'
            width = 2
        self.canvas.draw_face(face, color, width)

    def callback_update_frame(self):
        # This is the callback method, polls the frames queue for images
        if not self.q_frames.empty():
            img, face = self.q_frames.get()
            if face is not None:
                self.draw_face_in_canvas(face)

                state = self.get_state()
                if state == 'enforce':
                    msg = self.handle_enforce(face)
                elif state == 'auto_adjust':
                    msg = self.handle_auto_adjust(face)
                self.canvas.draw_msg(msg)

            self.canvas.draw_img(img)
        
        self.canvas.after(self._frame_time, self.callback_update_frame)


class ControlsFrame(tk.Frame):
    def __init__(self, root, parent):
        tk.Frame.__init__(self, master=parent)

        self._buttoms_disabled = False
        self.root = root
        self.parent = parent

        def show_hide_camera():
            self.root.q_control.put('show_hide_camera')

        def auto_adjust():
            self.root.set_state('auto_adjust')

        def stop_resume():
            # This could use after_cancel instead of statuses?
            self.root.q_control.put('start_stop')

            self._buttoms_disabled = not self._buttoms_disabled
            if self._buttoms_disabled:
                state = 'disabled'
            else:
                state = 'normal'
            #self.b_show_hide.config(state=state)
            self.b_show_hide['state'] = state
            self.b_auto_adjust.config(state=state)
            self.root.canvas.hide_face()

        self.b_show_hide = tk.Button(self, text='Toggle camera show/hide', width=20,
                                      command=show_hide_camera, font='Helvetica 13')
        self.b_show_hide.grid()

        self.b_auto_adjust = tk.Button(self, text='Auto adjust protocol', width=20,
                                      command=auto_adjust, font='helvetica 13', 
                                      fg='grey')
        self.b_auto_adjust.grid()

        self.b_full_stop = tk.Button(self, text='Stops/Resumes capturing', width=20,
                                      command=stop_resume, font='helvetica 13', 
                                      fg='grey')
        self.b_full_stop.grid()

        self.b_quit = tk.Button(self, text='Quit', width=20,
                                command=root.destroy, font='Helvetica 13')
        self.b_quit.grid()


class WebCanvas(tk.Canvas):
    def __init__(self, parent, width, height, background, margin):
        tk.Canvas.__init__(self, master=parent, width=width, height=height, background=background)

        self._n_lines = 40
        self._margin = margin
        self._white_img = Image.new("RGB", [width, height], (84, 84, 84))#, (255,255,255))

        self.width = width
        self.webcam = self.create_image(margin, margin,
                                            anchor=tk.NW, image=None)
        self.face = self.create_oval(0, 0, 0, 0,
                                     outline="SpringGreen2", width=1, dash=(4, 4))
        self.pos = self.create_text(0, 0,
                                    fill="white",font="Helvetica 13",text="")
        self.msg = self.create_text(5, 5,
                                    fill="white",font="Helvetica 13",text="", anchor=tk.NW)
        self.select_line = self.create_line(0, 0, 0, 0,
                                            fill='red', width=1, dash=(3,3))
        self.limit_line = self.create_line(0, 0, 0, 0,
                                           fill='red', width=2)
        for l in range(self._n_lines):
            obj = self.create_line(0, 0, 0, 0,
                                   fill='red2', width=1, dash=(3,3))
            setattr(self, 'line' + str(l), obj )

    def draw_y_limit(self, y):
        self.coords(self.limit_line, 0, y, self.width, y)
        pos_x = 0 
        for l in range(self._n_lines):
            pos_x += self.width / float(self._n_lines)
            obj = getattr(self, 'line' + str(l))
            self.coords(obj, pos_x, 150, pos_x, y)

    def draw_img(self, img):
        if img is not None:
            img = Image.fromarray(img)
            imgtk = ImageTk.PhotoImage(image=img)
        else:
            imgtk = ImageTk.PhotoImage(image=self._white_img)
        self.imgtk = imgtk
        self.itemconfig(self.webcam, image=self.imgtk)

    def draw_msg(self, msg):
        if msg is None:
            msg = ''
        self.itemconfig(self.msg, text=msg)
        
    def draw_face(self, face, colour, width):
        x, y, w, h = face
        self.coords(self.face,
                          x + self._margin, y + self._margin,
                          x + w + self._margin, y + h + self._margin)

        self.itemconfig(self.face, outline=colour, width=width)

        #self.canvas.coords(self.canvas.pos, 2 * x, y + h / 2.0)
        #self.canvas.itemconfig(self.canvas.pos, text='x=%s y=%s' % (x, y))

    def hide_face(self):
        self.coords(self.face, 0, 0, 0, 0)


    

