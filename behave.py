import multiprocessing
from tk_gui import gui_mainloop
from proc_capturer import cam_loop

if __name__ == '__main__':
    logger = multiprocessing.log_to_stderr()
    logger.setLevel(multiprocessing.SUBDEBUG)

    #Queue len of 3 gives some buffer?
    q_frames_captured = multiprocessing.Queue(1)
    q_from_gui = multiprocessing.Queue(1)
    q_to_capturer = multiprocessing.Queue(1)

    e_frame_captured = multiprocessing.Event()
    e_from_gui = multiprocessing.Event()

    p_gui = multiprocessing.Process(target=gui_mainloop,args=(q_frames_captured, q_from_gui, e_frame_captured, e_from_gui))

    p_cap = None
    try:
        p_gui.start()
        print 'proces p_gui is started with PID "%s"' % p_gui.pid

        # control loop:
        while True:

            # waits for the gui to say something::
            e_from_gui.wait()

            control = ''
            if not q_from_gui.empty():
                control = q_from_gui.get()
                print 'GET from gui %s' % control
                if control == 'start':
                    print 'creting capturer process'
                    p_cap = multiprocessing.Process(target=cam_loop,
                            args=(q_frames_captured, q_to_capturer, e_frame_captured))
                    print 'webcam capture process received "start" from gui'
                    p_cap.start()
                    print 'proces p_cap is started with PID "%s"' % p_cap.pid

                if control == 'stop':
                    print 'webcam capture process received "stop" from gui'
                    q_to_capturer.put('stop')

                    p_cap.join()
                    print 'p_cap process has joined'

                if control == 'show_hide_camera':
                    print 'received show/hide from gui'
                    q_to_capturer.put('show_hide_camera')
            
                if control == 'quit':
                    #BUG: quit cannot happen without having it started:
                    print ' received quit from gui'

                    # stopping p_cap process
                    if p_cap:
                        print 'Entering to stop p_cap'
                        q_to_capturer.put('stop')
                        print 'it does the put'
                        #FIXME: p_cap.join()
                        p_cap.terminate()
                        print 'p_cap process has joined'

                    break

            # clears the event so it waits again.
            e_from_gui.clear()


        p_gui.join()
        print 'p_gui process has joined'

    except KeyboardInterrupt:
        p_cap.terminate()
        p_gui.terminate()


"""
from multiprocessing import Process, freeze_support

def f():
    print 'hello world!'

if __name__ == '__main__':
    freeze_support()
    Process(target=f).start()
"""
