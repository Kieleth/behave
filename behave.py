import multiprocessing

def cam_loop(the_q, event):
    import cv2
    width, height = 800, 600
    cap = cv2.VideoCapture(0)
    cap.set(cv2.CAP_PROP_FRAME_WIDTH, width)
    cap.set(cv2.CAP_PROP_FRAME_HEIGHT, height)
    
    while True:
        _ , img = cap.read()
        if img is not None:
            img = cv2.flip(img, 1)
            img = cv2.cvtColor(img, cv2.COLOR_BGR2RGBA)
            the_q.put(img)
            event.set()


if __name__ == '__main__':

    try:
        logger = multiprocessing.log_to_stderr()
        logger.setLevel(multiprocessing.SUBDEBUG)

        the_q = multiprocessing.Queue(1)

        event = multiprocessing.Event()
        cam_process = multiprocessing.Process(target=cam_loop,args=(the_q, event))
        cam_process.start()

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

        def gui_mainloop(the_q, event):
            gui = TkGui()
            while True:
                event.wait()
                img = the_q.get()
                gui.update_frame(img)

        gui_mainloop(the_q, event)

        cam_process.join()

    except KeyboardInterrupt:
        cam_process.terminate()

