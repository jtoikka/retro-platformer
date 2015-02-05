import 'dart:html';
import 'dart:web_gl';

import 'package:game_loop/game_loop_html.dart';

import 'stateMachine.dart';
import 'input.dart';

CanvasElement canvas;
RenderingContext gl;
StateMachine stateMachine;

double leftOverTime = 0.0;

void update(GameLoopHtml gameLoop) {
    double time = gameLoop.accumulatedTime + leftOverTime;
    checkInput(gameLoop, time);
    const double delta = 0.015;
    while (time >= delta) {
        stateMachine.update(delta);
        time -= delta;
    }
    leftOverTime = time;
    stateMachine.clearInput();
    //stateMachine.update(time);
}

void render(GameLoopHtml gameLoop) {
    stateMachine.render(gl);
}

void checkInput(GameLoopHtml gameLoop, double time) {
    if (gameLoop.keyboard.isDown(KeyCode.W)) {
        stateMachine.input(Input.UP, time);
    }
    if (gameLoop.keyboard.isDown(KeyCode.A)) {
        stateMachine.input(Input.LEFT, time);
    }
    if (gameLoop.keyboard.isDown(KeyCode.S)) {
        stateMachine.input(Input.DOWN, time);
    }
    if (gameLoop.keyboard.isDown(KeyCode.D)) {
        stateMachine.input(Input.RIGHT, time);
    }
    if (gameLoop.keyboard.isDown(KeyCode.SPACE)) {
        stateMachine.input(Input.JUMP, time);
    }
    if (gameLoop.keyboard.isDown(KeyCode.PERIOD)) {
        stateMachine.input(Input.ACTION, time);
    }
}

void main() {
    canvas = querySelector("#webGLCanvas");
    print("Get canvas");
    gl = canvas.getContext("webgl");
    if (gl == null) {
        gl = canvas.getContext("experimental-webgl");
        if (gl == null) {
            return;
        }
    }

    stateMachine = new StateMachine(gl, 320, 240, canvas.width, canvas.height);

    GameLoopHtml gameLoop = new GameLoopHtml(canvas);
    gameLoop.onUpdate = update;
    gameLoop.onRender = render;
    gameLoop.start();
}