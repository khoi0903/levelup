package vn.levelup.exercises;

import java.util.List;

import org.springframework.data.mongodb.repository.MongoRepository;

public interface ExerciseRepository extends MongoRepository<Exercise, String> {

    List<Exercise> findByIsActiveTrue();
}
