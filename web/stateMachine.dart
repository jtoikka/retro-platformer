library stateMachine;

import 'dart:web_gl';

import 'state.dart';
import 'renderer.dart';
import 'eventmanager.dart';

class StateMachine {
    State _activeState;
    Renderer _renderer;
    EventManager _eventManager;
    Listener _listener;

    GameState _gameState;

    StateMachine(RenderingContext gl, int w, int h, int canvasW, int canvasH) {
        _eventManager = new EventManager();
        _listener = new Listener();
        _eventManager.addListener("stateMachine", _listener);
        _gameState = new GameState(w, h, canvasW, canvasH, _eventManager);
        _activeState = _gameState;
        _renderer = new Renderer(gl, w, h);
    }

    void render(RenderingContext gl) {
        _activeState.render(gl, _renderer);
    }

    void update(double time) {
        _eventManager.delegateEvents();
        _activeState.update(time, _eventManager);
    }

    void input(int inputType, double time) {
        _activeState.input(inputType, time);
    }

    void clearInput() {
        _activeState.clearInput();
    }
}