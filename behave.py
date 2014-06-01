import multiprocessing
from tk_gui import gui_mainloop
from proc_capturer import cam_loop

if __name__ == '__main__':
    logger = multiprocessing.log_to_stderr()
    logger.setLevel(multiprocessing.SUBDEBUG)

    q_frames_captured = multiprocessing.Queue(3)
    e_frame_captured = multiprocessing.Event()

    p_cap = multiprocessing.Process(target=cam_loop,args=(q_frames_captured, e_frame_captured))
    p_gui = multiprocessing.Process(target=gui_mainloop,args=(q_frames_captured, e_frame_captured))

    try:
        p_cap.start()
        p_gui.start()

        p_cap.join()
        p_gui.join()

    except KeyboardInterrupt:
        p_cap.terminate()
        p_gui.terminate()

