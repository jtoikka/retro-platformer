library Entity;

import 'package:vector_math/vector_math.dart';

import 'eventmanager.dart';

class Component {}

class SpatialComponent extends Component {
    Vector2 position = new Vector2(0.0, 0.0);
    bool facingRight = true;
    Vector2 deltaPosition;
    Entity onPlatform = null;
}

class PhysicsComponent extends Component {
    Vector2 velocity = new Vector2(0.0, 0.0);
    Vector2 acceleration = new Vector2(0.0, 0.0);
    Vector2 maxVelocity = new Vector2(80.0, 150.0);
    double gravity = -120.0;
    double mass = 10.0;
    double jumpTimerMin = 0.1;
    double jumpTimerMax = 0.5;
    double jumpTimer = 0.0;
    bool onGround = false;
    bool jumping = false;
    bool flying = false;
    bool gliding = false;
    bool isPlatform = false;
}

class CollisionComponent extends Component {
    static const int BOX = 1;
    static const int PLAYER = 2;
    static const int ENEMY = 3;
    static const int DOOR = 4;
    static const int EXIT = 5;
    Vector4 collisionBox = new Vector4(8.0, 8.0, 0.0, 0.0); // w, h, offset
    int type = BOX;
}

class PlayerStateComponent extends Component {
    bool crouching = false;
}

class GrabComponent extends Component {
    Entity held = null;
    Vector2 offset = new Vector2(0.0, 7.0);
}

class GrabbableComponent extends Component {
    Entity grabbedBy = null;
}

class RenderComponent extends Component {
    String spriteSheet = "objects";
    String sprite = "crate";
}

class AnimationComponent extends Component {
    static const int PLAYER = 1;
    static const int FLYING = 2;

    int type = 0;

    String animation;

    double timer = 0.0;
    String currentSprite;

    String state = "";
}

class ExitComponent extends Component {
    String room;
    Vector2 position; // The position the player will enter the new room in.
}

class AIComponent extends Component {
    double timer = 0.0;
}

class HealthComponent extends Component {
    double health;
}

class DamageComponent extends Component {
    double damage;
}

class Entity {
    String id;
	Map<Type, Component> components;

	Listener listener;

	Entity(String id) {
	    this.id = id;
	    components = new Map();
	}

	void addComponent(var component) {
	    components[component.runtimeType] = component;
	}

	Component getComponent(Type type) {
		if (components.containsKey(type)) {
		    return components[type];
		}
		return null;
	}
}