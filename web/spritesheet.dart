library SpriteSheet;

import 'dart:web_gl';
import 'dart:html';
import 'dart:typed_data';

import 'package:vector_math/vector_math.dart';

class Sprite {
    Buffer vertices;
    Buffer texCoords;
}

class SpriteSheet {

    Texture texture;

    ImageElement image;

    Map<String, Sprite> sprites;

    double width, height;

    SpriteSheet(RenderingContext gl, String source, double w, double h) {
        sprites = new Map();

        width = w;
        height = h;

        texture = gl.createTexture();
        gl.bindTexture(TEXTURE_2D, texture);
        gl.texParameteri(TEXTURE_2D, TEXTURE_MIN_FILTER, NEAREST);
        gl.texParameteri(TEXTURE_2D, TEXTURE_MAG_FILTER, NEAREST);
        gl.texParameteri(TEXTURE_2D, TEXTURE_WRAP_S, CLAMP_TO_EDGE);
        gl.texParameteri(TEXTURE_2D, TEXTURE_WRAP_T, CLAMP_TO_EDGE);
        gl.bindTexture(TEXTURE_2D,  null);

        image = new ImageElement(src: source);
        image.onLoad.listen((event) {
            gl.bindTexture(TEXTURE_2D, texture);
            gl.texImage2DImage(TEXTURE_2D, 0, RGBA, RGBA, UNSIGNED_BYTE, image);
            gl.bindTexture(TEXTURE_2D,  null);
        });
    }

    void addSprite(RenderingContext gl, Vector4 dimensions, Vector4 segment, String name) {
        Sprite sprite = new Sprite();
        sprite.vertices = gl.createBuffer();
        sprite.texCoords = gl.createBuffer();

        List vertices = [dimensions.z, dimensions.y,
                         dimensions.z, dimensions.w,
                         dimensions.x, dimensions.y,
                         dimensions.x, dimensions.w];

        List texCoords = [segment.z / width, segment.w / height,
                          segment.z / width, segment.y / height,
                          segment.x / width, segment.w / height,
                          segment.x / width, segment.y / height];

        gl.bindBuffer(ARRAY_BUFFER, sprite.vertices);
        gl.bufferData(ARRAY_BUFFER, new Float32List.fromList(vertices), STATIC_DRAW);

        gl.bindBuffer(ARRAY_BUFFER, sprite.texCoords);
        gl.bufferData(ARRAY_BUFFER, new Float32List.fromList(texCoords), STATIC_DRAW);

        sprites[name] = sprite;
    }
}