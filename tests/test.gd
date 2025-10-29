extends GdUnitTestSuite

func test_example():
 assert_str("This is an example message")\
   .has_length(26)\
   .starts_with("This is an ex")

func test_example2():
 assert_str("This is an example message")\
   .has_length(26)\
   .starts_with("This is an ex")
