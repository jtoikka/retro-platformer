library Camera;

import 'room.dart';
import 'package:vector_math/vector_math.dart';

class Camera {
    Room room; // The room the camera is currently within
    Vector2 location; // Coordinates of the camera

    Camera(double x, double y) {
        this.room = room;
        location = new Vector2(x, y);
    }
}