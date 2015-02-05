library State;

import 'dart:web_gl';
import 'dart:html';
import 'dart:convert';
import 'dart:math';

import 'package:vector_math/vector_math.dart';

import 'level.dart';
import 'renderer.dart';
import 'entity.dart';
import 'physics.dart';
import 'input.dart';
import 'factory.dart';
import 'animation.dart';
import 'eventmanager.dart';

abstract class State {
    void update(double time, EventManager eventManager);
    void render(RenderingContext gl, Renderer renderer);
    void input(int inputType, double direction);
    void clearInput();
}

class GameState extends State {
    List<Level> _levels;
    Level _activeLevel;
    Entity _camera;
    Entity _player;
    Map<int, double> _inputs;
    Listener _listener;

    int internalWidth, internalHeight, canvasWidth, canvasHeight;

    Map<int, Entity> entities;

    Map<String, SpriteAnimation> animations;

    Physics physics;

    GameState(int internalW, int internalH, int canvasW,
              int canvasH, EventManager eventManager) {
        internalWidth = internalW;
        internalHeight = internalH;
        canvasWidth = canvasW;
        canvasHeight = canvasH;
        buildAnimations();

        _listener = new Listener();
        eventManager.addListener("gameState", _listener);

        _levels = new List();
        _levels.add(new Level());

        _activeLevel = _levels[0];

        entities = _activeLevel.currentRoom.entities;
        _camera = Factory.createCamera("camera");

        _player = Factory.createPlayer("player");
        _player.listener = new Listener();

        eventManager.addListener(_player.id, _player.listener);

        entities[_player.hashCode] = _player;

        _inputs = new Map();

        physics = new Physics();
    }

    bool jumpUnlocked = false;

    bool loadPhysics = true;

    void handleStateEvents() {
        for (GameEvent event in _listener.events) {
            if (event.args["loadRoom"] != null) {
                toss(_player);
                _activeLevel.setRoom(event.args["loadRoom"]);
                SpatialComponent spatial = _player.getComponent(SpatialComponent);
                spatial.position = event.args["playerLocation"] * 16.0;
                loadPhysics = true;
                entities = _activeLevel.currentRoom.entities;
                entities[_player.hashCode] = _player;
            }
        }
        _listener.events.clear();
    }

    void update(double time, EventManager eventManager) {
        handleStateEvents();
        if (_activeLevel.currentRoom.loading) {
            print("Loading room");
            return;
        } else if (loadPhysics){
            physics.setRoom(_activeLevel.currentRoom);
            physics.addDynamicEntity(_player);
            print("add player");
            loadPhysics = false;
        }
        SpatialComponent sComp = _player.getComponent(SpatialComponent);
        handleInput(_player, time);

        physics.step(eventManager);
        for (Entity entity in entities.values) {
            // Update grabbed
            handleAI(entity, time);
            handleEvents(entity);
            GrabComponent grab = entity.getComponent(GrabComponent);
            PhysicsComponent phys = entity.getComponent(PhysicsComponent);
            if (grab != null && grab.held != null) {
                SpatialComponent spatial = entity.getComponent(SpatialComponent);
                SpatialComponent heldSpatial = grab.held.getComponent(SpatialComponent);
                CollisionComponent collision = grab.held.getComponent(CollisionComponent);
                PhysicsComponent heldPhys = grab.held.getComponent(PhysicsComponent);
                heldSpatial.position = spatial.position + grab.offset + new Vector2(0.0, collision.collisionBox.y - collision.collisionBox.w);
                heldSpatial.facingRight = sComp.facingRight;
                if (heldPhys.flying) {
                    phys.gliding = true;
                }
            } else {
                if (phys != null)
                    phys.gliding = false;
            }
            updateAnimation(entity, time);
        }

        // Update cam
        SpatialComponent cSComp = _camera.getComponent(SpatialComponent);
        cSComp.position = sComp.position.clone();

        double w = internalWidth / 2.0;
        double h = internalHeight / 2.0;
        // Attempt to center camera on player, set within level bounds.
        int tileSize = _activeLevel.currentRoom.tileSize;
        if (cSComp.position.x < w - tileSize / 2.0) {
            cSComp.position.x = w - tileSize / 2.0;
        } else if (cSComp.position.x > _activeLevel.currentRoom.width * tileSize - w- tileSize/2.0) {
            cSComp.position.x = _activeLevel.currentRoom.width * tileSize - w - tileSize/2.0;
        }

        if (cSComp.position.y < h - tileSize/2.0) {
            cSComp.position.y = (h - tileSize/2.0).floor().toDouble();
        } else if (cSComp.position.y > _activeLevel.currentRoom.height * tileSize - h - tileSize/2.0) {
            cSComp.position.y = _activeLevel.currentRoom.height * tileSize - h - tileSize/2.0;
        }
    }



    void handleAI(Entity entity, double time) {
        AIComponent ai = entity.getComponent(AIComponent);
        if (ai != null) {
            double s = sin((ai.timer) * PI / 2.0) * 0.3;
            ai.timer += time;
            SpatialComponent spatial = entity.getComponent(SpatialComponent);
            spatial.position += new Vector2(0.0, s);
            PhysicsComponent pComp = entity.getComponent(PhysicsComponent);

            if (spatial.facingRight) {
                pComp.velocity.x = 22.0;
            } else {
                pComp.velocity.x = -22.0;
            }
        }
    }

    void handleEvents(Entity entity) {
        if (entity.listener != null) {
            for (GameEvent event in entity.listener.events) {
                if (event.args["takeDamage"] != null) {
                    Entity collider = event.args["takeDamage"];
                    SpatialComponent spatial = entity.getComponent(SpatialComponent);
                    if (spatial.onPlatform != collider) {
                        Vector2 intersection = event.args["intersection"];
                        Vector2 collision = new Vector2(intersection.x / intersection.x.abs(), 0.0) * -500.0;
                        Physics.impulse(entity, collision);
                    }
                }
            }
            entity.listener.events.clear();
        }
    }

    void updateAnimation(Entity entity, double time) {
        AnimationComponent anim = entity.getComponent(AnimationComponent);
        if (anim == null) {
            return;
        }
        if (anim.type == AnimationComponent.PLAYER) {
            updatePlayerAnimation(entity, time);
        }
        else if (anim.type == AnimationComponent.FLYING) {
            SpatialComponent sComp = entity.getComponent(SpatialComponent);
            if (sComp.facingRight) {
                anim.state = "bat_right";
            } else {
                anim.state = "bat_left";
            }
            anim.timer += time;
            SpriteAnimation animation = animations[anim.animation];
            Loop loop = animation.loops[anim.state];
            anim.currentSprite = loop.getFrame(anim.timer);
        }
    }

    void updatePlayerAnimation(Entity entity, double time) {
        AnimationComponent anim = entity.getComponent(AnimationComponent);
        PhysicsComponent phys = entity.getComponent(PhysicsComponent);
        SpatialComponent spatial = entity.getComponent(SpatialComponent);
        if (anim != null) {
            anim.timer += time;
            String currentState = "idle_left";
            if (phys != null) {
                if (phys.onGround) {
                    if (spatial.facingRight) {
                        if (phys.velocity.x > 0.0) {
                            currentState = "run_right";
                        } else {
                            currentState = "idle_right";
                        }
                    } else {
                        if (phys.velocity.x < 0.0) {
                            currentState = "run_left";
                        } else {
                            currentState = "idle_left";
                        }
                    }
                } else {
                    if (spatial.facingRight) {
                        if (phys.velocity.y > 0.0)
                            currentState = "jump_right";
                        else
                            currentState = "fall_right";
                    } else {
                        if (phys.velocity.y > 0.0)
                            currentState = "jump_left";
                        else
                            currentState = "fall_left";
                    }
                }
            }
            GrabComponent grab = entity.getComponent(GrabComponent);
            if (grab.held != null) {
                currentState += "_hold";
            }
            if (currentState != anim.state) {
                anim.timer = 0.0;
            }
            anim.state = currentState;
            SpriteAnimation animation = animations[anim.animation];
            if (animation != null) {
                Loop loop = animation.loops[anim.state];
                if (loop != null) {
                    anim.currentSprite = loop.getFrame(anim.timer);
                } else {
                    print(anim.state);
                }
            } else {
                print("animation null");
            }
        }
    }

    bool actionHeld = false;

    void handleInput(Entity player, double time) {
        PhysicsComponent pComp = player.getComponent(PhysicsComponent);
        SpatialComponent sComp = player.getComponent(SpatialComponent);
        PlayerStateComponent state = player.getComponent(PlayerStateComponent);
        if (_inputs.containsKey(Input.LEFT)) {
            sComp.facingRight = false;
            if (pComp.onGround) {
                Physics.impulse(player, new Vector2(-135.0, 0.0));
            } else {
                Physics.impulse(player, new Vector2(-75.0, 0.0));
            }
        }
        if (_inputs.containsKey(Input.RIGHT)) {
            sComp.facingRight = true;
            if (pComp.onGround) {
                Physics.impulse(player, new Vector2(145.0, 0.0));
            } else {
                Physics.impulse(player, new Vector2(75.0, 0.0));
            }
        }
        if (_inputs.containsKey(Input.DOWN)) {
            state.crouching = true;
        } else {
            state.crouching = false;
        }
        if (_inputs.containsKey(Input.ACTION)) {
            if (!actionHeld) {
                actionHeld = true;
                GrabComponent grab = _player.getComponent(GrabComponent);
                if (grab.held != null) {
                    toss(_player);
                } else if (state.crouching) {
                    if (pComp.onGround) {
                        pickup(player);
                    }
                }
            }
        } else {
            actionHeld = false;
        }

        if (_inputs.containsKey(Input.JUMP)) {
            if (jumpUnlocked) {
                if (pComp.onGround) {
                    pComp.jumping = true;
                }
                jumpUnlocked = false;
            }
            if (pComp.jumpTimer > pComp.jumpTimerMax) {
                pComp.jumping = false;
            }
        } else {
            if (pComp.onGround) {
                jumpUnlocked = true;
            }
            if (pComp.jumpTimer > pComp.jumpTimerMin) {
                pComp.jumping = false;
            }
        }
        if (pComp.jumping == true) {
            pComp.jumpTimer += time;
            sComp.onPlatform = null;
            Physics.impulse(_player, new Vector2(0.0, 26.0 / (pComp.jumpTimer)));
        }
    }

    void pickup(Entity entity) {
        SpatialComponent spatial = entity.getComponent(SpatialComponent);
        Entity platform = spatial.onPlatform;
        if (platform != null) {
            GrabbableComponent grabbable = platform.getComponent(GrabbableComponent);
            if (grabbable != null) {
                physics.removeDynamic(platform);
                GrabComponent grab = entity.getComponent(GrabComponent);
                grab.held = platform;
                grabbable.grabbedBy = entity;
                spatial.onPlatform = null;
                return;
            }
        }
        spatial.position.y -= 0.001;
        Entity collider = physics.checkBelow(entity);
        if (collider == null) {
            return;
        } else {
            GrabbableComponent grabbable = collider.getComponent(GrabbableComponent);
            if (grabbable != null) {
                physics.removeDynamic(collider);
                GrabComponent grab = entity.getComponent(GrabComponent);
                grab.held = collider;
                grabbable.grabbedBy = entity;
            }
        }
    }

    void toss(Entity entity) {
        GrabComponent grab = entity.getComponent(GrabComponent);
        SpatialComponent spatial = entity.getComponent(SpatialComponent);
        if (grab.held == null) {
            return;
        }
        SpatialComponent heldSpatial = grab.held.getComponent(SpatialComponent);
        PhysicsComponent entPhysics = entity.getComponent(PhysicsComponent);
        PhysicsComponent heldPhysics = grab.held.getComponent(PhysicsComponent);

        heldSpatial.position.y += 2.0;
        heldPhysics.velocity = entPhysics.velocity / 2.0;

        double xImpulse = spatial.facingRight ? 5000.0 : -5000.0;
        Physics.impulse(grab.held, new Vector2(xImpulse, 5000.0));
        physics.addDynamicEntity(grab.held);
        GrabbableComponent grabbable = grab.held.getComponent(GrabbableComponent);
        grabbable.grabbedBy = null;

        grab.held = null;
    }

    void clearInput() {
        _inputs.clear();
    }

    void render(RenderingContext gl, Renderer renderer) {
        if (_activeLevel.currentRoom.loading) {
            return;
        }
        renderer.startRendering(gl);
        gl.clear(COLOR_BUFFER_BIT);
        renderer.renderRoom(gl, _activeLevel.currentRoom, _camera);
        renderer.renderEntities(gl, entities, _camera, animations);
        renderer.finishRendering(gl, _player, _camera, animations, canvasWidth, canvasHeight);
    }

    void input(int inputType, double direction) {
        _inputs[inputType] = direction;
    }

    void buildAnimations() {
        print("Building animations");
        animations = new Map();

        HttpRequest.getString("data/animation.json").then(
        (String jsonString) {
            Map animationData = JSON.decode(jsonString);

            Map anims = animationData["animations"];
            anims.forEach((String key, Map animation) {
                SpriteAnimation anim = new SpriteAnimation(key);
                anim.spriteSheet = animation["spriteSheet"];
                animation["loops"].forEach((Map v) {
                    Loop loop = new Loop(v["duration"]);
                    for (String frame in v["frames"]) {
                        loop.frames.add(frame);
                    }
                    anim.loops[v["name"]] = loop;
                });
                animations[key] = anim;
            });
        });
    }
}