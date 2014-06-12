from multiprocessing import Process, Queue, freeze_support
from proc_capturer import cam_loop


        
if __name__ == '__main__':
    freeze_support()
    #logger = multiprocessing.log_to_stderr()
    #logger.setLevel(multiprocessing.SUBDEBUG)

    q_frames = Queue(1)
    q_control = Queue(1)

    print( 'creating capturer process')
    p_cap = Process(target=cam_loop,
            args=(q_frames, q_control))
    p_cap.start()
    print( 'proces p_cap is started with PID "%s"' % p_cap.pid)

    print ('Tkinter is starting')
    # BUG in tkinter-multiprocessing, tkimport after the process fork:
    from tk_gui import TkGui
    gui = TkGui(q_frames, q_control)
    gui.update_frame()
    gui.mainloop()

    p_cap.terminate()

