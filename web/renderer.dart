library Renderer;

import 'dart:typed_data';
import 'dart:web_gl';
import 'dart:html';
import 'dart:convert';

import 'package:vector_math/vector_math.dart';

import 'room.dart';
import 'shader_manager.dart';
import 'entity.dart';
import 'spritesheet.dart';

class BufferCombo {
    Buffer vertexBuffer;
    Buffer uvBuffer;
    int numTriangles;
}

class Renderer {
    final int SCALE = 3;
    int resolutionX;
    int resolutionY;

    Buffer tileBuffer;
    Buffer uvBuffer;
    Buffer foregroundBuffer;
    Buffer foregroundUVBuffer;
    Buffer nearBuffer;
    Buffer nearUVBuffer;
    Buffer backgroundBuffer;
    Buffer backgroundUVBuffer;

    Buffer screenBuffer;
    Buffer screenUVBuffer;

    UniformLocation colourUnif;

    Framebuffer fbo1;
    Framebuffer fbo2;
    Texture fboTex;
    Texture fbo2Tex;

    Texture grilleTex;
    Texture scanlineTex;

    Room currentRoom;
    int foregroundNumTriangles = 0;
    int backgroundNumTriangles = 0;
    int nearNumTriangles = 0;

    ShaderManager shaderManager;

    Map<String, SpriteSheet> spriteSheets;

    bool loadingSprites = true;

    Matrix3 transformMatrix;

    Renderer(RenderingContext gl, int w, int h) {
        var extension = gl.getExtension("OES_texture_float");
        if (extension == null) {
            print("Texture float not supported");
        }

        loadApertureGrille(gl);

        resolutionX = w;
        resolutionY = h;
        buildTileBuffer(gl, 16, 16);

        shaderManager = new ShaderManager();
        shaderManager.initProgram(gl, "tile", "#tile-vs", "#tile-fs");
        shaderManager.initProgram(gl, "screen", "#screen-vs", "#screen-fs");
        shaderManager.initProgram(gl, "interpolatex",
                                  "#interpolatex-vs", "#interpolatex-fs");
        shaderManager.attachTexture(gl, "tile", "sprite", 0);
        shaderManager.attachTexture(gl, "screen", "screenTex", 0);
        shaderManager.attachTexture(gl, "tile", "grilleTex", 1);
        shaderManager.attachTexture(gl, "tile", "scanlineTex", 2);

        colourUnif = gl.getUniformLocation(
            shaderManager.getProgram("tile").handle, "baseColour");

        var program = shaderManager.getProgram("tile");

        var unif = gl.getUniformLocation(program.handle, "transformMat");
        program.unifs["transformMat"] = unif;

        transformMatrix = new Matrix3.identity();
        transformMatrix[0] = 1.0 / (w / 2.0);
        transformMatrix[4] = 1.0 / (h / 2.0);

        gl.disable(CULL_FACE);
        gl.clearColor(0.0 / 255.0, 0.0 / 255.0, 0.0 / 252.0, 255.0 / 255.0);

        gl.enable(BLEND);
        gl.blendFunc(SRC_ALPHA, ONE_MINUS_SRC_ALPHA);

        spriteSheets = new Map();

        loadSprites(gl);
        genFramebuffer(gl);
        initScreenQuad(gl);
    }

    Texture genTexture(RenderingContext gl, int internalFormat,
                       int w, int h, int format, int type) {
        Texture tex = gl.createTexture();
        gl.bindTexture(TEXTURE_2D, tex);
        gl.texImage2DTyped(TEXTURE_2D, 0, internalFormat, w,
                           h, 0, format, type, null);
        gl.texParameteri(TEXTURE_2D, TEXTURE_MIN_FILTER, NEAREST);
        gl.texParameteri(TEXTURE_2D, TEXTURE_MAG_FILTER, NEAREST);
        gl.texParameteri(TEXTURE_2D, TEXTURE_WRAP_S, CLAMP_TO_EDGE);
        gl.texParameteri(TEXTURE_2D, TEXTURE_WRAP_T, CLAMP_TO_EDGE);

        return tex;
    }

    void loadApertureGrille(RenderingContext gl) {
        grilleTex = gl.createTexture();
        gl.bindTexture(TEXTURE_2D, grilleTex);
        gl.texParameteri(TEXTURE_2D, TEXTURE_MIN_FILTER, NEAREST);
        gl.texParameteri(TEXTURE_2D, TEXTURE_MAG_FILTER, NEAREST);
        gl.texParameteri(TEXTURE_2D, TEXTURE_WRAP_S, REPEAT);
        gl.texParameteri(TEXTURE_2D, TEXTURE_WRAP_T, REPEAT);
        gl.bindTexture(TEXTURE_2D,  null);

        scanlineTex = gl.createTexture();
        gl.bindTexture(TEXTURE_2D, scanlineTex);
        gl.texParameteri(TEXTURE_2D, TEXTURE_MIN_FILTER, NEAREST);
        gl.texParameteri(TEXTURE_2D, TEXTURE_MAG_FILTER, NEAREST);
        gl.texParameteri(TEXTURE_2D, TEXTURE_WRAP_S, REPEAT);
        gl.texParameteri(TEXTURE_2D, TEXTURE_WRAP_T, REPEAT);
        gl.bindTexture(TEXTURE_2D,  null);


        ImageElement image =
            new ImageElement(src: "data/aperture grille.png");
        image.onLoad.listen((event) {
            gl.bindTexture(TEXTURE_2D, grilleTex);
            gl.texImage2DImage(TEXTURE_2D, 0, RGBA, RGBA, FLOAT, image);
            gl.bindTexture(TEXTURE_2D,  null);
        });
        ImageElement scanlineImage =
            new ImageElement(src: "data/scanline.png");
        image.onLoad.listen((event) {
            gl.bindTexture(TEXTURE_2D, scanlineTex);
            gl.texImage2DImage(TEXTURE_2D, 0, RGBA, RGBA, FLOAT, scanlineImage);
            gl.bindTexture(TEXTURE_2D,  null);
        });
    }

    void genFramebuffer(RenderingContext gl) {
        fboTex = genTexture(gl, RGBA, resolutionX * SCALE,
                            resolutionY * SCALE, RGBA, FLOAT);
        fbo2Tex = genTexture(gl, RGBA, resolutionX * SCALE,
                             resolutionY * SCALE, RGBA, FLOAT);

        fbo1 = gl.createFramebuffer();
        gl.bindFramebuffer(FRAMEBUFFER, fbo1);
        gl.framebufferTexture2D(FRAMEBUFFER, COLOR_ATTACHMENT0,
                                TEXTURE_2D, fboTex, 0);

        var FBOstatus = gl.checkFramebufferStatus(FRAMEBUFFER);
        if (FBOstatus != FRAMEBUFFER_COMPLETE) {
            print("ERROR: Framebuffer incomplete");
        }

        fbo2 = gl.createFramebuffer();
        gl.bindFramebuffer(FRAMEBUFFER, fbo2);
        gl.framebufferTexture2D(FRAMEBUFFER, COLOR_ATTACHMENT0,
                                TEXTURE_2D, fbo2Tex, 0);
        FBOstatus = gl.checkFramebufferStatus(FRAMEBUFFER);
        if (FBOstatus != FRAMEBUFFER_COMPLETE) {
            print("ERROR: Framebuffer incomplete");
        }

        gl.bindFramebuffer(FRAMEBUFFER, null);
    }

    void loadSpriteSheet(RenderingContext gl, String location,
                         double w, double h, String name) {
        spriteSheets[name] = new SpriteSheet(gl, location, w, h);
    }

    void loadSprites(RenderingContext gl) {
        loadSpriteSheet(gl, "data/objects copy.png",
                        1024.0, 1024.0, "objects");
        loadSpriteSheet(gl, "data/tileMap copy.png",
                        1024.0, 1024.0, "tileMap.png");
        loadSpriteSheet(gl, "data/playersprite copy.png",
                        512.0, 512.0, "characters");
        loadSpriteSheet(gl, "data/aperture grille.png",
                        3.0, 3.0, "grille");

        HttpRequest.getString("data/sprites.json")
        .then((String jsonString) {
            Map data = JSON.decode(jsonString);
            Map spriteData = data["sprites"];

            spriteData.forEach((String name, Map sprite) {
                double w = sprite["width"];
                double h = sprite["height"];
                double locX = sprite["location_x"] * 16.0 * w;
                double loc2X = sprite["location_x"] * 16.0 * w;
                if (sprite["flip_x"]) {
                    locX += 16.0 * w;
                } else {
                    loc2X += 16.0 * w;
                }
                double locY = sprite["location_y"] * 16.0 * h;
                double loc2Y = sprite["location_y"] * 16.0 * h;
                if (sprite["flip_y"]) {
                    locY += 16.0 * h;
                } else {
                    loc2Y += 16.0 * h;
                }
                // Note: offset not yet handled
                spriteSheets[sprite["spriteSheet"]].addSprite(
                    gl, new Vector4(-8.0 * w,
                                    -8.0 * h,
                                     8.0 * w,
                                     8.0 * h),
                    new Vector4(locX, locY, loc2X, loc2Y),
                    name
                );
            });
            loadingSprites = false;
        });
    }

    void buildTileBuffer(RenderingContext gl, int w, int h) {
        tileBuffer   = gl.createBuffer();
        uvBuffer = gl.createBuffer();

        double hw = w / 2.0; // Half width
        double hh = h / 2.0; // Half height

        var vertices = [ hw, -hh,
                         hw,  hh,
                        -hw, -hh,
                        -hw,  hh];

        var texCoords = [1.0, 1.0,
                         1.0, 0.0,
                         0.0, 1.0,
                         0.0, 0.0];

        gl.bindBuffer(ARRAY_BUFFER, tileBuffer);
        gl.bufferData(ARRAY_BUFFER,
                      new Float32List.fromList(vertices), STATIC_DRAW);

        gl.bindBuffer(ARRAY_BUFFER, uvBuffer);
        gl.bufferData(ARRAY_BUFFER,
                      new Float32List.fromList(texCoords), STATIC_DRAW);
    }

    void startRendering(RenderingContext gl) {
        var program = shaderManager.getProgram("tile");
        gl.useProgram(program.handle);
        gl.bindFramebuffer(FRAMEBUFFER, fbo1);
        gl.viewport(0, 0, resolutionX * SCALE, resolutionY * SCALE);
    }

    void finishRendering(RenderingContext gl, Entity player,
                         Entity camera, Map animations, int w, int h) {
        renderHUD(gl);
        gl.bindFramebuffer(FRAMEBUFFER, fbo2);
        var program = shaderManager.getProgram("interpolatex");
        gl.useProgram(program.handle);
        gl.clear(COLOR_BUFFER_BIT);
        renderTexToScreen(gl, fboTex, program);

        gl.bindFramebuffer(FRAMEBUFFER, null);
        gl.viewport(0, 0, w, h);
        program = shaderManager.getProgram("screen");
        gl.useProgram(program.handle);
        gl.clear(COLOR_BUFFER_BIT);

        gl.activeTexture(TEXTURE1);
        gl.bindTexture(TEXTURE_2D, grilleTex);

        gl.activeTexture(TEXTURE2);
        gl.bindTexture(TEXTURE_2D, scanlineTex);

        renderTexToScreen(gl, fbo2Tex, program);
    }

    void initScreenQuad(RenderingContext gl) {
            screenBuffer = gl.createBuffer();
            screenUVBuffer = gl.createBuffer();

            var vertices = [ 1.0, -1.0,
                             1.0,  1.0,
                            -1.0, -1.0,
                            -1.0,  1.0];

            var uv = [1.0, 0.0,
                      1.0, 1.0,
                      0.0, 0.0,
                      0.0, 1.0];


            gl.bindBuffer(ARRAY_BUFFER, screenBuffer);
            gl.bufferData(ARRAY_BUFFER,
                          new Float32List.fromList(vertices), STATIC_DRAW);

            gl.bindBuffer(ARRAY_BUFFER, screenUVBuffer);
            gl.bufferData(ARRAY_BUFFER,
                          new Float32List.fromList(uv), STATIC_DRAW);
        }

    void renderTexToScreen(RenderingContext gl, Texture tex, var program) {
        gl.bindBuffer(ARRAY_BUFFER, screenBuffer);
        gl.vertexAttribPointer(program.vertex, 2, FLOAT, false, 0, 0);

        gl.bindBuffer(ARRAY_BUFFER, screenUVBuffer);
        gl.vertexAttribPointer(program.uv, 2, FLOAT, false, 0, 0);

        gl.activeTexture(TEXTURE0);
        gl.bindTexture(TEXTURE_2D, tex);

        gl.drawArrays(TRIANGLE_STRIP, 0, 4);
    }


    BufferCombo bufferLayer(RenderingContext gl, Room room, List layer) {
        List vertices = new List();
        List uvs = new List();
        int numTriangles = 0;
        for (int i = 0; i < layer.length; i++) {
            if (layer[i] != 0) {
                int x = (i % room.width) * 16;
                int y = (room.height - 1) * room.tileSize
                      - (i ~/ room.width) * 16;
                vertices.add(x - 8.0); vertices.add(y - 8.0);
                vertices.add(x + 8.0); vertices.add(y - 8.0);
                vertices.add(x + 8.0); vertices.add(y + 8.0);

                vertices.add(x - 8.0); vertices.add(y - 8.0);
                vertices.add(x + 8.0); vertices.add(y + 8.0);
                vertices.add(x - 8.0); vertices.add(y + 8.0);

                int tileWidth = room.tileSet.tileWidth;
                int tileSheetWidth = (room.tileSet.imageWidth
                                   ~/ room.tileSet.tileWidth);

                int tileSheetY = ((layer[i] - 1) ~/ tileSheetWidth);
                int tileSheetX = (layer[i] - 1) % tileSheetWidth;

                double uvX1 = (tileSheetX * tileWidth)
                            / room.tileSet.imageWidth;
                double uvX2 = ((tileSheetX + 1) * tileWidth)
                            / room.tileSet.imageWidth;

                double uvY1 = (tileSheetY * tileWidth)
                            / room.tileSet.imageWidth;
                double uvY2 = ((tileSheetY + 1) * tileWidth)
                            / room.tileSet.imageWidth;

                uvs.add(uvX1); uvs.add(uvY2);
                uvs.add(uvX2); uvs.add(uvY2);
                uvs.add(uvX2); uvs.add(uvY1);

                uvs.add(uvX1); uvs.add(uvY2);
                uvs.add(uvX2); uvs.add(uvY1);
                uvs.add(uvX1); uvs.add(uvY1);
                numTriangles += 6;
            }
        }
        BufferCombo buffer = new BufferCombo();
        buffer.vertexBuffer = gl.createBuffer();
        buffer.uvBuffer = gl.createBuffer();
        buffer.numTriangles = numTriangles;

        gl.bindBuffer(ARRAY_BUFFER, buffer.vertexBuffer);
        gl.bufferData(ARRAY_BUFFER,
                      new Float32List.fromList(vertices), STATIC_DRAW);

        gl.bindBuffer(ARRAY_BUFFER, buffer.uvBuffer);
        gl.bufferData(ARRAY_BUFFER,
                      new Float32List.fromList(uvs), STATIC_DRAW);

        return buffer;
    }

    void bufferRoom(RenderingContext gl, Room room) {
        BufferCombo buffer = bufferLayer(gl, room,
                                         room.layers["foreground"].tiles);
        foregroundBuffer = buffer.vertexBuffer;
        foregroundUVBuffer = buffer.uvBuffer;
        foregroundNumTriangles = buffer.numTriangles;

        BufferCombo buffer2 = bufferLayer(gl, room,
                                          room.layers["background"].tiles);
        backgroundBuffer = buffer2.vertexBuffer;
        backgroundUVBuffer = buffer2.uvBuffer;
        backgroundNumTriangles = buffer2.numTriangles;

        BufferCombo buffer3 = bufferLayer(gl, room, room.layers["near"].tiles);
        nearBuffer = buffer3.vertexBuffer;
        nearUVBuffer = buffer3.uvBuffer;
        nearNumTriangles = buffer3.numTriangles;

    }

    void renderRoom(RenderingContext gl, Room room, Entity camera) {
        if (loadingSprites) {
            return;
        }
        SpatialComponent sComp = camera.getComponent(SpatialComponent);

        var program = shaderManager.getProgram("tile");
        if (currentRoom != room) {
            currentRoom = room;
            bufferRoom(gl, room);
        }

        gl.activeTexture(TEXTURE0);
        gl.bindTexture(TEXTURE_2D, spriteSheets["tileMap.png"].texture);

        Matrix3 mat = new Matrix3(1.0, 0.0, 0.0,
                                  0.0, 1.0, 0.0,
                                  -sComp.position.x.round().toDouble(),
                                  -sComp.position.y.round().toDouble(), 1.0);
        mat =  transformMatrix * mat;

        gl.uniformMatrix3fv(program.unifs["transformMat"], false, mat.storage);

        gl.bindBuffer(ARRAY_BUFFER, backgroundBuffer);
        gl.vertexAttribPointer(program.vertex, 2, FLOAT, false, 0, 0);

        gl.bindBuffer(ARRAY_BUFFER, backgroundUVBuffer);
        gl.vertexAttribPointer(program.uv, 2, FLOAT, false, 0, 0);

        gl.drawArrays(TRIANGLES, 0, backgroundNumTriangles);

        gl.bindBuffer(ARRAY_BUFFER, nearBuffer);
       gl.vertexAttribPointer(program.vertex, 2, FLOAT, false, 0, 0);

       gl.bindBuffer(ARRAY_BUFFER, nearUVBuffer);
       gl.vertexAttribPointer(program.uv, 2, FLOAT, false, 0, 0);

       gl.drawArrays(TRIANGLES, 0, nearNumTriangles);

        gl.bindBuffer(ARRAY_BUFFER, foregroundBuffer);
        gl.vertexAttribPointer(program.vertex, 2, FLOAT, false, 0, 0);

        gl.bindBuffer(ARRAY_BUFFER, foregroundUVBuffer);
        gl.vertexAttribPointer(program.uv, 2, FLOAT, false, 0, 0);

        gl.drawArrays(TRIANGLES, 0, foregroundNumTriangles);
    }

    void renderEntities(RenderingContext gl, Map entities,
                        Entity camera, Map animations) {
        if (loadingSprites) {
            return;
        }
        gl.uniform4f(colourUnif, 1.0, 1.0, 1.0, 1.0);
        for (Entity entity in entities.values) {
            renderEntity(gl, entity, camera, animations, 1.0);
        }
    }

    void renderEntity(RenderingContext gl, Entity entity, Entity camera,
                      Map animations, double scale) {
        SpatialComponent sComp = entity.getComponent(SpatialComponent);
        RenderComponent rComp = entity.getComponent(RenderComponent);
        if (sComp == null || rComp == null) {
            return;
        }
        var program = shaderManager.getProgram("tile");

        AnimationComponent anim = entity.getComponent(AnimationComponent);

        SpriteSheet sheet;
        Sprite sprite;

        if (anim != null) {
            sheet = spriteSheets[animations[anim.animation].spriteSheet];
            sprite = sheet.sprites[anim.currentSprite];
        } else {
            sheet = spriteSheets[rComp.spriteSheet];
            if (sheet == null) {
                print(rComp.spriteSheet);
                return;
            }
            sprite = sheet.sprites[rComp.sprite];
        }
        if (sprite != null) {
            gl.activeTexture(TEXTURE0);
            gl.bindTexture(TEXTURE_2D, sheet.texture);
            gl.bindBuffer(ARRAY_BUFFER, sprite.vertices);
            gl.vertexAttribPointer(program.vertex, 2, FLOAT, false, 0, 0);

            gl.bindBuffer(ARRAY_BUFFER,
                          sprite.texCoords);
            gl.vertexAttribPointer(program.uv, 2, FLOAT, false, 0, 0);
        }
        SpatialComponent cSComp = camera.getComponent(SpatialComponent);

        // Calculate translation (matrix) using camera position.
        // Values are rounded to align pixels to grid.
        double relativeX = (sComp.position.x.round()
                         - cSComp.position.x.round()).toDouble();
        double relativeY = (sComp.position.y.round()
                         - cSComp.position.y.round()).toDouble();

        Matrix3 mat = new Matrix3(scale, 0.0, 0.0,
                                  0.0, scale, 0.0,
                                  relativeX, relativeY, 1.0);

        mat =  transformMatrix * mat;

        gl.uniformMatrix3fv(program.unifs["transformMat"], false, mat.storage);
        gl.drawArrays(TRIANGLE_STRIP, 0, 4);
    }

    void renderHUD(RenderingContext gl) {
        var program = shaderManager.getProgram("tile");
        SpriteSheet sheet = spriteSheets["objects"];
        Sprite sprite = sheet.sprites["heart_full"];
        gl.activeTexture(TEXTURE0);
        gl.bindTexture(TEXTURE_2D, sheet.texture);

        gl.bindBuffer(ARRAY_BUFFER, sprite.vertices);
        gl.vertexAttribPointer(program.vertex, 2, FLOAT, false, 0, 0);

        gl.bindBuffer(ARRAY_BUFFER, sprite.texCoords);
        gl.vertexAttribPointer(program.uv, 2, FLOAT, false, 0, 0);

        void renderHeart(offsetX, offsetY) {
            Matrix3 mat = new Matrix3(1.0, 0.0, 0.0,
                                      0.0, 1.0, 0.0,
                                      offsetX, offsetY, 1.0);
            mat =  transformMatrix * mat;
            gl.uniformMatrix3fv(program.unifs["transformMat"], false, mat.storage);
            gl.drawArrays(TRIANGLE_STRIP, 0, 4);
        }

        double offsetX = -resolutionX / 2.0 + 16.0;
        double offsetY = resolutionY / 2.0 - 16.0;
        renderHeart(offsetX, offsetY);
        renderHeart(offsetX, offsetY - 10.0);
        renderHeart(offsetX, offsetY - 20.0);
    }
}