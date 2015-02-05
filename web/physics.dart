library Physics;

import 'package:vector_math/vector_math.dart';

import 'entity.dart';
import 'room.dart';
import 'eventmanager.dart';

const double GRAVITY = -120.0;

const double FRICTION = 140.0;

const double AIRRESISTANCE = 20.0;

const double TIMESTEP = 0.015;

class Physics {

    Room room;

    Map<int, Entity> dynamicEntities;
    Map<int, Entity> staticEntities;

    Entity tileEntity; // This is for checking room tile collisions. The tile is
                       // moved to the appropriate location when testing for
                       // intersections.

    Physics() {
        dynamicEntities = new Map();
        staticEntities = new Map();

        tileEntity = new Entity("tile");
        CollisionComponent collision = new CollisionComponent();
        tileEntity.addComponent(collision);
        SpatialComponent spatial = new SpatialComponent();
        tileEntity.addComponent(spatial);
    }

    void setRoom(Room room) {
        dynamicEntities.clear();
        staticEntities.clear();
        this.room = room;
        for (Entity entity in room.entities.values) {
            if (entity.getComponent(PhysicsComponent) != null) {
                dynamicEntities[entity.hashCode] = entity;
            } else if (entity.getComponent(CollisionComponent) != null) {
                staticEntities[entity.hashCode] = entity;
            }
        }
    }

    void addDynamicEntity(Entity entity) {
        dynamicEntities[entity.hashCode] = entity;
    }

    void step(EventManager eventManager) {
        for (Entity entity in dynamicEntities.values) {
            applyPhysics(entity, TIMESTEP, eventManager);
        }
    }

    void applyPhysics(Entity entity, double delta, EventManager eventManager) {
        PhysicsComponent pComp = entity.getComponent(PhysicsComponent);
        SpatialComponent sComp = entity.getComponent(SpatialComponent);

        if (pComp == null || sComp == null) {
            return;
        }

        Entity platform = sComp.onPlatform;
        if (platform != null) {
            sComp.position.y -= 1.0;
            if (checkCollision(entity, platform, eventManager)) {
                PhysicsComponent platformPhys = platform.getComponent(PhysicsComponent);
                SpatialComponent platformSpatial = platform.getComponent(SpatialComponent);
                CollisionComponent platformCol = platform.getComponent(CollisionComponent);
                CollisionComponent collision = entity.getComponent(CollisionComponent);
                sComp.position.y = platformSpatial.position.y
                                 + collision.collisionBox.y
                                 + collision.collisionBox.w
                                 + platformCol.collisionBox.y
                                 + platformCol.collisionBox.w;
                sComp.position.x += platformSpatial.deltaPosition.x;

                pComp.onGround = true;
            } else {
                sComp.onPlatform = null;
            }
        } else {
            if (!pComp.flying)
                pComp.acceleration.y += pComp.gravity;
        }

        Vector2 displacement = pComp.velocity * delta
                             + pComp.acceleration * 0.5 * delta * delta;
        var acc = pComp.velocity;
        Vector2 newVelocity = pComp.velocity + pComp.acceleration * delta;
        if (newVelocity.x.abs() < pComp.maxVelocity.x) {
            pComp.velocity.x = newVelocity.x;
        } else {
            pComp.velocity.x = (pComp.velocity.x / pComp.velocity.x.abs())
                               * pComp.maxVelocity.x;
        }
        if (newVelocity.y.abs() < pComp.maxVelocity.y){
            pComp.velocity.y = newVelocity.y;
        } else {
            pComp.velocity.y = (pComp.velocity.y / pComp.velocity.y.abs())
                               * pComp.maxVelocity.y;
        }
        if(pComp.gliding) {
            if (pComp.velocity.y < -17.0) {
                pComp.velocity.y = -17.0;
            }
        }

        sComp.deltaPosition = displacement;
        sComp.position += displacement;

        bool collidedBelow = false;

        Vector2 intersection = checkRoomCollision(entity, room);
        if (intersection.y < 0.0) {
            collidedBelow = true;
        }

        for (Entity collider in dynamicEntities.values) {
            if (entity == collider) continue;
            checkCollision(entity, collider, eventManager);
        }

        for (Entity collider in staticEntities.values) {
            if (entity.getComponent(PhysicsComponent) != null) {
                checkStaticCollision(entity, collider, eventManager);
            }
        }

        if (pComp.acceleration.x == 0.0
         || pComp.acceleration.x < 0 != pComp.velocity.x < 0) {
            // decelerate ground
            if (pComp.velocity.x != 0.0) {
                if (pComp.velocity.y == 0.0) {
                    // Check if positive or negative
                    double sign = (pComp.velocity.x / pComp.velocity.x.abs());
                    pComp.velocity.x -= FRICTION * delta * sign;
                } else { // decelerate air
                    double sign = (pComp.velocity.x / pComp.velocity.x.abs());
                    pComp.velocity.x -= AIRRESISTANCE * delta * sign;
                }
            }
        }

        double threshold = 1.0;

        if (pComp.velocity.x.abs() < threshold) {
            pComp.velocity.x = 0.0;
        }
        if (pComp.velocity.y.abs() < threshold) {
            pComp.velocity.y = 0.0;
        }

        pComp.acceleration = new Vector2(0.0, 0.0);
        if (pComp.velocity.y != 0.0) {
            pComp.onGround = false;
        }
        if (sComp.onPlatform != null) {
            pComp.onGround = true;
            pComp.jumpTimer = 0.0;
        }
    }


    void removeDynamic(Entity entity) {
        dynamicEntities.remove(entity.hashCode);
    }

    Entity checkBelow(Entity entity) {
        for (Entity collider in dynamicEntities.values) {
            if (entity == collider) continue;
            SpatialComponent spatialA = entity.getComponent(SpatialComponent);
            SpatialComponent spatialB = collider.getComponent(SpatialComponent);


            CollisionComponent collisionA = entity.getComponent(CollisionComponent);
            CollisionComponent collisionB = collider.getComponent(CollisionComponent);
            Vector2 diff = spatialA.position - spatialB.position;

            if (diff.y < 0.0) {
                continue;
            }

            Vector2 intersection = checkIntersection(entity, collider);
            if (intersection.x != 0.0 && intersection.y != 0.0) {
                return collider;
            }
        }
        return null;
    }

    bool checkCollision(Entity entityA, Entity entityB, EventManager eventManager) {
        CollisionComponent collisionA = entityA.getComponent(CollisionComponent);
        CollisionComponent collisionB = entityB.getComponent(CollisionComponent);

        Entity dominant = entityA;
        Entity recessive = entityB;

        if (collisionA.type == CollisionComponent.PLAYER) {
            dominant = entityB;
            recessive = entityA;
        }

        if (collisionA.type == collisionB.type) {
            PhysicsComponent phys = entityA.getComponent(PhysicsComponent);
            if (phys.velocity != new Vector2(0.0, 0.0)) {
                recessive = entityA;
                dominant = entityB;
            }
        }

        SpatialComponent spatialA = recessive.getComponent(SpatialComponent);
        SpatialComponent spatialB = dominant.getComponent(SpatialComponent);

        PhysicsComponent physicsA = recessive.getComponent(PhysicsComponent);
        PhysicsComponent physicsB = dominant.getComponent(PhysicsComponent);


        void resolveCollision(Vector2 intersection) {
            CollisionComponent rCollision = recessive.getComponent(CollisionComponent);
            CollisionComponent dCollision = dominant.getComponent(CollisionComponent);
            if (rCollision.type == CollisionComponent.PLAYER
             && dCollision.type == CollisionComponent.BOX) {
                if (physicsA.velocity.y < 0.0
                && (intersection.y.abs() < 2.9) && intersection.y < 0.0) {
                    spatialA.position.y -=intersection.y;
                    physicsA.onGround = true;
                    physicsA.jumpTimer = 0.0;
                    physicsA.velocity.y = 0.0;
                    if (physicsB.isPlatform) {
                        spatialA.onPlatform = dominant;
                    }
                }
                return;
            }
            if (rCollision.type == CollisionComponent.PLAYER
                   && dCollision.type == CollisionComponent.ENEMY) {
                if (!(physicsA.velocity.y < 0.0
                  && (intersection.y.abs() < 2.9) && intersection.y < 0.0)) {
                    GameEvent event = new GameEvent();
                    event.args["takeDamage"] = dominant;
                    event.args["intersection"] = intersection;
                    event.recipients.add(recessive.id);
                    eventManager.addEvent(event);
                    return;
                }
            }
            if ((intersection.x.abs() <= intersection.y.abs()
             || intersection.y == 0.0) && intersection.x != 0.0) {
                spatialA.position.x -= intersection.x;
                physicsA.velocity.x = 0.0;
            } else {
                spatialA.position.y -=intersection.y;
                if (physicsA.velocity.y < 0.0) {
                    physicsA.onGround = true;
                    physicsA.jumpTimer = 0.0;
                    if (physicsB.isPlatform) {
                        spatialA.onPlatform = dominant;
                    }
                }
                if (!physicsA.jumping)
                    physicsA.velocity.y = 0.0;
            }
        }

        Vector2 intersection = checkIntersection(recessive, dominant);
        if (intersection.x != 0.0 && intersection.y != 0.0) {
            resolveCollision(intersection);
            return true;
        }
        return false;
    }

    Vector2 checkIntersection(Entity entityA, Entity entityB) {
        SpatialComponent spatialA = entityA.getComponent(SpatialComponent);
        SpatialComponent spatialB = entityB.getComponent(SpatialComponent);

        CollisionComponent collisionA = entityA.getComponent(CollisionComponent);
        CollisionComponent collisionB = entityB.getComponent(CollisionComponent);

        Vector2 diff = spatialA.position + collisionA.collisionBox.zw
                    - (spatialB.position + collisionB.collisionBox.zw);

        double xDiff = diff.x.abs()
                     - (collisionA.collisionBox.x + collisionB.collisionBox.x);

        double yDiff = diff.y.abs()
                     - (collisionA.collisionBox.y + collisionB.collisionBox.y);

        if (xDiff < 0 && yDiff < 0) {
            Vector2 intersection = new Vector2(0.0, 0.0);
            if (diff.x != 0.0) {
                intersection.x = xDiff * diff.x / diff.x.abs();
            }
            if (diff.y != 0.0) {
                intersection.y = yDiff * diff.y / diff.y.abs();
            }
            return intersection;
        }
        return new Vector2(0.0, 0.0);
    }

    Vector2 checkStaticCollision(Entity dynamicEntity, Entity staticEntity,
                              EventManager eventManager) {
        CollisionComponent dynamicCol = dynamicEntity.getComponent(CollisionComponent);
        CollisionComponent staticCol = staticEntity.getComponent(CollisionComponent);

        SpatialComponent dynamicSpatial = dynamicEntity.getComponent(SpatialComponent);
        SpatialComponent staticSpatial = staticEntity.getComponent(SpatialComponent);

        PhysicsComponent dynamicPhysics = dynamicEntity.getComponent(PhysicsComponent);


        void resolveCollision(Vector2 intersection) {
            if (staticCol.type == CollisionComponent.EXIT
             && dynamicCol.type == CollisionComponent.PLAYER) {
                GameEvent event = new GameEvent();
                ExitComponent exit = staticEntity.getComponent(ExitComponent);
                event.args["loadRoom"] = exit.room;
                event.args["playerLocation"] = exit.position;
                event.recipients = ["gameState"];
                eventManager.addEvent(event);
                return;
            }
            if ((intersection.x.abs() <= intersection.y.abs()
             || intersection.y == 0.0) && intersection.x != 0.0) {
                dynamicSpatial.position.x -= intersection.x;
                dynamicPhysics.velocity.x = 0.0;
            } else {
                dynamicSpatial.position.y -=intersection.y;
                if (dynamicPhysics.velocity.y < 0.0) {
                    dynamicPhysics.onGround = true;
                    dynamicPhysics.jumpTimer = 0.0;
                }
                dynamicPhysics.velocity.y = 0.0;
            }
        }

        Vector2 intersection = checkIntersection(dynamicEntity, staticEntity);
        if (intersection.x != 0.0 && intersection.y != 0.0) {
            resolveCollision(intersection);
        }
        return intersection;
    }

    Vector2 checkRoomCollision(Entity entity, Room room) {
        CollisionComponent cComp = entity.getComponent(CollisionComponent);
        SpatialComponent sComp = entity.getComponent(SpatialComponent);
        PhysicsComponent pComp = entity.getComponent(PhysicsComponent);
        if (cComp == null || sComp == null || pComp == null) {
            return new Vector2(0.0, 0.0);
        }

        void resolveCollision(Vector2 intersection, int testMask) {
            bool checkY = true;
            bool checkX = true;
            if ((testMask & 0x1 == 0 && intersection.y < 0.0)
             || (testMask & 0x4 == 0 && intersection.y > 0.0)) {
                checkY = false;
            }
            if ((testMask & 0x2 == 0 && intersection.x < 0.0)
             || (testMask & 0x8 == 0 && intersection.x > 0.0)) {
                checkX = false;
            }
            if ((intersection.x.abs() <= intersection.y.abs()
             || intersection.y == 0.0 || !checkY) && intersection.x != 0.0 && checkX) {
                sComp.position.x -= intersection.x;
                if (pComp.velocity.x < 0.0 == intersection.x < 0.0) {
                    pComp.velocity.x = 0.0;
                    if (pComp.flying) {
                        sComp.facingRight = !sComp.facingRight;
                    }
                }
            } else {
                sComp.position.y -=intersection.y;
                if (pComp.velocity.y < 0.0) {
                    pComp.onGround = true;
                    pComp.jumpTimer = 0.0;
                }
                if (pComp.velocity.y < 0.0 == intersection.y < 0.0) {
                    pComp.velocity.y = 0.0;
                }
            }
        }

        Vector2 axes = new Vector2(room.tileSize / 2.0 + cComp.collisionBox.x,
                                   room.tileSize / 2.0 + cComp.collisionBox.y);


        /*
        @param point The corner of the bounding box being tested
        @param collisionTest A bitmask continaing the directions to test in
                             (top, left, bottom, right).
        */
        Vector2 intersect = new Vector2(0.0, 0.0);

        bool check(Vector2 point) {
            int index = room.getTileIndex(point);
            if (index != null) {
                if (room.collisionArray[index] != 0) {
                    int toTest = room.collisionArray[index];
                    if (toTest == 0) {
                        return false;
                    }

                    Vector2 tileLocation = new Vector2(
                        ((index % room.width) * room.tileSize).toDouble(),
                        ((index ~/ room.width) * room.tileSize).toDouble());

                    SpatialComponent tileSpatial = tileEntity.getComponent(SpatialComponent);
                    tileSpatial.position = tileLocation;
                    Vector2 intersection = checkIntersection(entity, tileEntity);

                    if (!(intersection.x == 0.0 && intersection.y == 0.0)) {
                        resolveCollision(intersection, toTest);
                        checkRoomCollision(entity, room);
                        intersect = intersection;
                        return true;
                    }
                }
            }
            return false;
        }

        final Vector2 dir = new Vector2(1.0, -1.0);

        // Check four corners
        if (check(sComp.position + cComp.collisionBox.zw + cComp.collisionBox.xy.multiply(dir.yy))) return intersect;
        if (check(sComp.position + cComp.collisionBox.zw + cComp.collisionBox.xy.multiply(dir.xy))) return intersect;
        if (check(sComp.position + cComp.collisionBox.zw + cComp.collisionBox.xy.multiply(dir.xx))) return intersect;
        if (check(sComp.position + cComp.collisionBox.zw + cComp.collisionBox.xy.multiply(dir.yx))) return intersect;
        return intersect;
    }



    static void impulse(Entity entity, Vector2 amount) {
        PhysicsComponent pComp = entity.getComponent(PhysicsComponent);
        pComp.acceleration += amount;
    }
}