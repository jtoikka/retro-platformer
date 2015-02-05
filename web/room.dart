library Room;

import 'dart:html';
import 'dart:convert';
import 'dart:core';

import 'package:vector_math/vector_math.dart';

import 'entity.dart';
import 'factory.dart';

class Layer {
    List<int> tiles;
    int opacity = 0;
}

class TileSet {
    String image;
    int imageHeight;
    int imageWidth;
    int tileHeight;
    int tileWidth;
}

class Room {
    Map<int, Entity> entities;
    List<int> collisionArray;

    Map<String, Layer> layers;

    String tileSheet = "";

    bool loading = true;

    TileSet tileSet;

    //static const TILESIZE = 16;

    int tileSize = 0;

    int width;
    int height;

    Room(String url) {
        layers = new Map();
        entities = new Map();
        loadRoom(url);
    }

    void evaluateCollisionTiles() {
        List collisionData = layers["collision"].tiles;
        int offset = collisionData.length - 1;
        if (collisionData == null) {
            print("ERROR: No collision data");
            return;
        }
        for (int i = 0; i < width * height; i++) {
            int dataY = i ~/ width;
            int dataX = i % width;
            // Tiled maps are upside down
            offset = (height - dataY - 1) * width + dataX;
            if (collisionData[offset] == 0) {
                collisionArray[i] = 0;
                continue;
            }

            int getIndex(Vector2 location) {
                int ix = (location.x / tileSize).round();
                int iy = (location.y / tileSize).round();


                if (ix < 0 || ix >= width
                 || iy < 0 || iy >= height) {
                    return null;
                }
                return ix + (height - iy - 1) * width;
            }

            Vector2 location = new Vector2((i % width).toDouble(),
                                           (i ~/ width).toDouble());

            if (location.x < 0 || location.x >= width
             || location.y < 0 || location.y >= height) {
                continue;
            }
            int indexLeft = getIndex((location - new Vector2(1.0, 0.0)) * 16.0);
            int indexTop = getIndex((location + new Vector2(0.0, 1.0)) * 16.0);
            int indexRight = getIndex((location + new Vector2(1.0, 0.0)) * 16.0);
            int indexBottom = getIndex((location - new Vector2(0.0, 1.0)) * 16.0);

            // This ensures solid tiles are non-zero when collision information
            // is evaluated. It gets masked out in the end.
            int collision = 0x10;

            if (indexTop != null) {
                if (collisionData[indexTop] == 0) {
                    collision = collision | 0x1;
                }
            }

            if (indexRight != null) {
                if (collisionData[indexRight] == 0) {
                    collision = collision | 0x2;
                }
            }

            if (indexBottom != null) {
                if (collisionData[indexBottom] == 0) {
                    collision = collision | 0x4;
                }
            }

            if (indexLeft != null) {
                if (collisionData[indexLeft] == 0) {
                    collision = collision | 0x8;
                }
            }
            collisionArray[i] = collision;
        }
        for (int i = 0; i < width * height; i++) {
            collisionArray[i] = collisionArray[i] & 0xf;
        }
    }

    void loadRoom(String url) {
        HttpRequest.getString(url).then((String jsonString) {
            Map tiledData = JSON.decode(jsonString);

            width = tiledData["width"];
            height = tiledData["height"];
            tileSize = tiledData["tilewidth"];

            tileSet = new TileSet();

            Map tileSetData = tiledData["tilesets"][0];
            tileSet.image = tileSetData["image"];
            tileSet.imageHeight = tileSetData["imageheight"];
            tileSet.imageWidth = tileSetData["imagewidth"];
            tileSet.tileWidth = tileSetData["tilewidth"];
            tileSet.tileHeight = tileSetData["tileheight"];

            for (Map layerData in tiledData["layers"]) {
                if (layerData["objects"] != null) {
                    for (Map object in layerData["objects"]) {
                        Vector2 position = new Vector2(object["x"].toDouble(),
                                  (height * tileSize - object["y"]).toDouble());
                        if (object["type"] == "box") {
                            Entity entity = Factory.createBox(object["name"],position);
                            entities[entity.hashCode] = entity;
                        } else if (object["type"] == "door") {
//                            Entity entity = Factory.createDoor(position);
//                            entities[entity.hashCode] = entity;
//                            print("added door");
                        } else  if (object["type"] == "exit") {
                            print("Creating exit");
                            Map properties = object["properties"];
                            Entity entity = Factory.createExit(
                                object["name"],
                                position, properties["room"],
                                new Vector2(
                                    double.parse(properties["entryPos_x"]),
                                    double.parse(properties["entryPos_y"])));
                            entities[entity.hashCode] = entity;
                        } else if (object["type"] == "bat") {
                            Entity entity = Factory.createBat(object["name"],
                                                              position);
                            entities[entity.hashCode] = entity;
                        }
                    }
                } else {
                    Layer layer = new Layer();
                    layer.tiles = layerData["data"];
                    layer.opacity = layerData["opacity"];
                    layers[layerData["name"]] = layer;
                }
            }
            collisionArray = new List(width * height);
            evaluateCollisionTiles();
            loading = false;
        });
    }

    int getTileIndex(Vector2 location) {
        int ix = (location.x / tileSize).round();
        int iy = (location.y / tileSize).round();


        if (ix < 0 || ix >= width
         || iy < 0 || iy >= height) {
            return null;
        }
        return ix + iy * width;
    }
}