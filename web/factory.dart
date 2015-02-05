library Factory;

import 'package:vector_math/vector_math.dart';

import 'entity.dart';

class Factory {

    static Entity createPlayer(String id) {
        Entity player = new Entity(id);

        SpatialComponent sComp = new SpatialComponent();
        sComp.position = new Vector2(120.0, 80.0);
        player.addComponent(sComp);

        PhysicsComponent pComp = new PhysicsComponent();
        pComp.maxVelocity = new Vector2(50.0, 150.0);
        pComp.isPlatform = true;
        player.addComponent(pComp);

        CollisionComponent cComp = new CollisionComponent();
        cComp.type = CollisionComponent.PLAYER;
        cComp.collisionBox = new Vector4(3.0, 8.0, 0.0, 0.0);
        player.addComponent(cComp);

        PlayerStateComponent state = new PlayerStateComponent();
        player.addComponent(state);

        GrabComponent grabber = new GrabComponent();
        player.addComponent(grabber);

        RenderComponent rComp = new RenderComponent();
        player.addComponent(rComp);

        AnimationComponent anim = new AnimationComponent();
        anim.animation = "playerAnim";
        anim.type = AnimationComponent.PLAYER;
        player.addComponent(anim);

        HealthComponent health = new HealthComponent();

        return player;
    }

    static Entity createBox(String id, Vector2 position) {
        Entity box = new Entity(id);

        SpatialComponent sComp = new SpatialComponent();
        sComp.position = position;
        box.addComponent(sComp);

        PhysicsComponent pComp = new PhysicsComponent();
        box.addComponent(pComp);

        CollisionComponent cComp = new CollisionComponent();
        box.addComponent(cComp);

        RenderComponent rComp = new RenderComponent();
        rComp.spriteSheet = "objects";
        rComp.sprite = "crate";
        box.addComponent(rComp);

        GrabbableComponent gComp = new GrabbableComponent();
        box.addComponent(gComp);

        return box;
    }

    static Entity createDoor(String id, Vector2 position) {
        Entity door = new Entity(id);

        SpatialComponent spatial = new SpatialComponent();
        spatial.position = position;
        door.addComponent(spatial);

        CollisionComponent collision = new CollisionComponent();
        collision.type = CollisionComponent.DOOR;
        collision.collisionBox = new Vector4(8.0, 16.0, 0.0, 0.0);
        door.addComponent(collision);

        RenderComponent render = new RenderComponent();
        door.addComponent(render);

        return door;
    }

    static Entity createExit(String id, Vector2 position, String room, Vector2 entryPos) {
        Entity exit = new Entity(id);

        SpatialComponent spatial = new SpatialComponent();
        spatial.position = position;
        exit.addComponent(spatial);

        CollisionComponent collision = new CollisionComponent();
        collision.type = CollisionComponent.EXIT;
        collision.collisionBox = new Vector4(8.0, 16.0, 0.0, 0.0);
        exit.addComponent(collision);

        ExitComponent exitComp = new ExitComponent();
        exitComp.room = room;
        exitComp.position = entryPos;
        exit.addComponent(exitComp);

        return exit;
    }

    static Entity createBat(String id, Vector2 position) {
        print("Adding bat");
        Entity bat = new Entity(id);

        SpatialComponent spatial = new SpatialComponent();
        spatial.position = position;
        spatial.facingRight = false;
        bat.addComponent(spatial);

        PhysicsComponent physics = new PhysicsComponent();
        physics.flying = true;
        physics.isPlatform = true;
        bat.addComponent(physics);

        RenderComponent render = new RenderComponent();
        bat.addComponent(render);

        AnimationComponent anim = new AnimationComponent();
        anim.animation = "batanim";
        anim.type = AnimationComponent.FLYING;
        bat.addComponent(anim);

        GrabbableComponent grabbable = new GrabbableComponent();
        bat.addComponent(grabbable);

        CollisionComponent collision = new CollisionComponent();
        collision.type = CollisionComponent.ENEMY;
        collision.collisionBox = new Vector4(5.0, 3.0, 0.0, -2.0);
        bat.addComponent(collision);

        AIComponent ai = new AIComponent();
        bat.addComponent(ai);

        return bat;
    }

    static Entity createCamera(String id) {
        Entity camera = new Entity(id);
        SpatialComponent cSComp = new SpatialComponent();
        cSComp.position = new Vector2(120.0, 80.0);
        camera.addComponent(cSComp);
        return camera;
    }
}