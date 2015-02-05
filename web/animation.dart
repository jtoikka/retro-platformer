library Animation;

class Loop {
    double duration;
    List<String> frames;

    Loop(double duration) {
        this.duration = duration;
        frames = new List();
    }

    String getFrame(double time) {
        // Convert to range [0.0, duration]
        double frameTime = time - (time / duration).floor().toDouble() * duration;
        int frameIndex = (frameTime / (duration / frames.length.toDouble())).floor();

        return frames[frameIndex];
    }
}

class SpriteAnimation {
    String spriteSheet;

    Map<String, Loop> loops;

    SpriteAnimation(String spriteSheet) {
        this.spriteSheet = spriteSheet;
        loops = new Map();
    }
}