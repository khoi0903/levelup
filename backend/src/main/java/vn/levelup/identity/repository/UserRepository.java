package vn.levelup.identity.repository;

import java.util.Optional;

import org.springframework.data.mongodb.repository.MongoRepository;
import vn.levelup.identity.model.User;

public interface UserRepository extends MongoRepository<User, String> {

    Optional<User> findByAuthUid(String authUid);
}
