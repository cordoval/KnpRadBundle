Feature: Domain events
    In order to keep a clean separation between domain logic and application implementation details
    As a developer
    I need rad bundle to provide a simple way to dispatch domain events

    Background:
        Given I write in "App/Entity/User.php":
        """
        <?php namespace App\Entity {
            /** @Doctrine\ORM\Mapping\Entity **/
            class User implements \Knp\RadBundle\DomainEvent\Provider
            {
                private $events = array();

                public function popEvents()
                {
                    $events = $this->events;
                    $this->events = array();

                    return $events;
                }

                /**
                 * @Doctrine\ORM\Mapping\Id
                 * @Doctrine\ORM\Mapping\GeneratedValue
                 * @Doctrine\ORM\Mapping\Column(type="integer")
                 **/
                private $id;

                /**
                 * @Doctrine\ORM\Mapping\Column(type="boolean")
                 **/
                private $isActivated = false;

                public function getId()
                {
                    return $this->id;
                }

                public function setId($id)
                {
                    $this->id = $id;
                }

                public function activate()
                {
                    $this->isActivated = true;
                    $this->events[] = new \Knp\RadBundle\DomainEvent\Event('UserActivated', array(
                        'user' => $this
                    ));
                }
            }
        }
        """
        And I write in "App/Controller/UserController.php":
        """
        <?php namespace App\Controller {
            class UserController extends \Knp\RadBundle\Controller\Controller
            {
                public function newAction() {
                    $user = new \App\Entity\User;
                    $user->activate();
                    $this->persist($user, true); // postFlush will dispatch UserActivated event
                    return new \Symfony\Component\HttpFoundation\Response;
                }
            }
        }
        """
        And I write in "App/SyncListener.php":
        """
        <?php namespace App {
            class SyncListener
            {
                public function onUserActivated(\Knp\RadBundle\DomainEvent\Event $event) {
                    var_dump($event->getName());
                }
            }
        }
        """
        And I write in "App/Resources/config/services.yml":
        """
        services:
            app.sync_listener:
                class: App\SyncListener
                tags:
                    - { name: doctrine.event_listener, event: onUserActivated }
        """
        And I write in "App/Resources/config/rad.yml":
        """
        App:User: ~
        """

    Scenario: using sync event listeners
        When I visit "app_user_new" page
        Then I should see "UserActivated"

    Scenario: using delayed event listeners
        Given I write in "App/AsyncListener.php":
        """
        <?php namespace App {
            class AsyncListener
            {
                public function onDelayedUserActivated(\Knp\RadBundle\DomainEvent\Event $event) {
                    file_put_contents(__DIR__.'/'.$event->getName(), $event->user->getId());
                }
            }
        }
        """
        And I write in "App/Resources/config/services.yml":
        """
        parameters:
            knp_rad.domain_event.delayed_event_names: [UserActivated]
        services:
            app.async_listener:
                class: App\AsyncListener
                tags:
                    - { name: doctrine.event_listener, event: onDelayedUserActivated }
        """
        When I visit "app_user_new" page
        Then the file "App/UserActivated" should contain "1"
