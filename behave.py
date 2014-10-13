from multiprocessing import Process, Queue, freeze_support
from proc_capturer import cam_loop
from sys import argv


FPS = 12
        
if __name__ == '__main__':
    # http://stackoverflow.com/a/5980173/1956309
    if '-d' in argv:
        def verboseprint(*args):
            for arg in args:
               print arg,
            #print
    else:   
        verboseprint = lambda *a: None
    #freeze_support()
    #logger = multiprocessing.log_to_stderr()
    #logger.setLevel(multiprocessing.SUBDEBUG)

    try:    
        q_frames = Queue(1)
        q_control = Queue(1)

        print( 'creating capturer process')
        p_capturer = Process(target=cam_loop,
                args=(q_frames, q_control, FPS, verboseprint))
        p_capturer.start()
        verboseprint( 'proces p_cap is started with PID "%s"' % p_capturer.pid)

        # BUG in tkinter-multiprocessing, tkimport after the process fork:
        from tk_gui import TkGui
        print ('Tkinter is starting')
        gui = TkGui(q_frames, q_control, FPS, verboseprint)
        gui.update_frame()
        gui.mainloop()

        p_capturer.terminate()

    except KeyboardInterrupt:
        gui.destroy()
        p_capturer.terminate()

#TODO:
# - add control to change resolution
# - add control to change the warning.
