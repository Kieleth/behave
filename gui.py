import cv2

def display_rectangle_coords(cv_image, x, y, w, h):
    """displays coords on screen"""
    cv2.putText(cv_image, "pos(x, y)=(%s,%s)" % (x, y), (x + w + 10, y + 15),
                cv2.FONT_HERSHEY_SIMPLEX, 0.5, (255,255,255))

    cv2.putText(cv_image, "size(w x h)=(%sx%s)" % (w, h), (x + w + 10, y + 40),
                cv2.FONT_HERSHEY_SIMPLEX, 0.5, (255,255,255))

def display_line(cv_img, coord1, coord2, color=(0, 0, 255), thickness=1):
    """ # Draw a diagonal blue line with thickness of 5 px
        cv2.line(img,(0,0),(511,511),(255,0,0),5)"""
    cv2.line(cv_img, coord1, coord2 , color=color, thickness=thickness)

def display_faces(cv_img, faces_list):
    """faces_list has format [(x, y, w, h), ..]"""
    for (x, y, w, h) in faces_list:
        #TODO: change rectangle for frame-like only corners.
        cv2.rectangle(cv_img, (x, y), (x + w, y + h), (255, 0, 0), 1)   
        display_line(cv_img, (0, y + h / 2), (x - 10, y + h /2), color=(0, 255, 0))
        #1280 should be passed somehow
        display_line(cv_img, (x + w + 10, y + h / 2), (1280, y + h /2), color=(0, 255, 0))
        display_rectangle_coords(cv_img, x, y, w, h)

def should_quit():
    #key handler:
    k = cv2.waitKey(1) & 0xFF
    if k == ord('q') or k == 27:
        return True
