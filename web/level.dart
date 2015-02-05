library Level;

import 'dart:html';

import 'room.dart';

class Level {
    Room currentRoom;

    Map<String, Room> rooms;

    Map<String, String> urls;

    Level() {
        rooms = new Map();
        urls = new Map();
        urls["testlvl1"] = "data/testlvl1.json";
        urls["testlvl2"] = "data/testlvl2.json";
        setRoom("testlvl1");
        currentRoom = rooms["testlvl1"];
    }

    void setRoom(String name) {
        if (rooms[name] == null) {
            loadRoom(name, urls[name]);
        }
        currentRoom = rooms[name];
    }

    void loadRoom(String name, String url) {
        Room room = new Room(url);
        rooms[name] = room;
    }

}