import cv2

def display_rectangle_coords(cv_image, x, y, w, h):
    """displays coords on screen"""
    cv2.putText(cv_image, "pos(x, y)=(%s,%s)" % (x, y), (x + w + 10, y + 15),
                cv2.FONT_HERSHEY_SIMPLEX, 0.5, (255,255,255))

    cv2.putText(cv_image, "size(w x h)=(%sx%s)" % (w, h), (x + w + 10, y + 40),
                cv2.FONT_HERSHEY_SIMPLEX, 0.5, (255,255,255))

def display_faces(cv_img, faces_list):
    """faces_list has format [(x, y, w, h), ..]"""
    for (x, y, w, h) in faces_list:
        cv2.rectangle(cv_img, (x, y), (x + w, y + h), (255, 0, 0), 2)
        display_rectangle_coords(cv_img, x, y, w, h)

def should_quit():
    #key handler:
    k = cv2.waitKey(1) & 0xFF
    if k == ord('q') or k == 27:
        return True