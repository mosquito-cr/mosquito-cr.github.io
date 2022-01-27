---
layout: manual
toc: false
title: Custom Serialization
---

In order to teach Mosquito how to serialize and de-serialize custom classes, define a method pair which handles the transformations and include it in the Job definition.

__This functionality should be avoided.__ Instead, simply handle (de)serialization on your own.

An example:

```crystal
class SpecialtyObject
  property name : String
  property value : Int32

  def initialize(@name, @value)
  end
end

module SpecialtyObjectMosquitoSerializer
  def serialize_specialty_object(specialty : SpecialtyObject) : String
    "#{specialty.name}=#{specialty.value}"
  end

  def deserialize_specialty_object(raw : String) : SpecialtyObject
    parts = raw.split "="
    SpecialtyObject.new name: parts.first, value: parts.last
  end
end

class MyJob < Mosquito::QueuedJob
  include SpecialtyObjectMosquitoSerializer

  params specialty_object : SpecialtyObject

  def perform
    # ...
  end
end
```
