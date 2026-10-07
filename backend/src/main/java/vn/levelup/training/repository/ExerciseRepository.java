package vn.levelup.training.repository;

import java.util.List;

import org.springframework.data.mongodb.repository.MongoRepository;
import vn.levelup.training.model.Exercise;

public interface ExerciseRepository extends MongoRepository<Exercise, String> {

    List<Exercise> findByIsActiveTrue();
}
