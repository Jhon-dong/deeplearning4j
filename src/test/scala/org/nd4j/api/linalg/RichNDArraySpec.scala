/*
 *
 *  * Copyright 2015 Skymind,Inc.
 *  *
 *  *    Licensed under the Apache License, Version 2.0 (the "License");
 *  *    you may not use this file except in compliance with the License.
 *  *    You may obtain a copy of the License at
 *  *
 *  *        http://www.apache.org/licenses/LICENSE-2.0
 *  *
 *  *    Unless required by applicable law or agreed to in writing, software
 *  *    distributed under the License is distributed on an "AS IS" BASIS,
 *  *    WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 *  *    See the License for the specific language governing permissions and
 *  *    limitations under the License.
 *
 *
 */

package org.nd4j.api.linalg

import org.junit.runner.RunWith
import org.nd4j.linalg.factory.Nd4j
import org.scalatest.junit.JUnitRunner
import org.scalatest.{FlatSpec, Matchers}
import org.nd4j.api.Implicits._

@RunWith(classOf[JUnitRunner])
class RichNDArraySpec extends FlatSpec with Matchers {
  "RichNDArray" should "use the apply method to access values" in {
    // -- 2D array
    val nd2 = Nd4j.create(Array[Double](1, 2, 3, 4), Array(4, 1))

    nd2.get(0) should be(1)
    nd2.get(3, 0) should be(4)

    // -- 3D array
    val nd3 = Nd4j.create(Array[Double](1, 2, 3, 4, 5, 6, 7, 8), Array(2, 2, 2))
    nd3.get(0, 0, 0) should be(1)
    nd3.get(1, 1, 1) should be(8)

  }

  it should "use transpose abbreviation" in {
    val nd1 = Nd4j.create(Array[Double](1, 2, 3), Array(3, 1))
    nd1.shape should equal(Array(3, 1))
    val nd1t = nd1.T
    nd1t.shape should equal(Array(1,3))
  }

  it should "add correctly" in {
    val a = Nd4j.create(Array[Double](1, 2, 3, 4, 5, 6, 7, 8), Array(2, 2, 2))
    val b = a + 100
    a.get(0, 0, 0) should be(1)
    b.get(0, 0, 0) should be(101)
    a += 1
    a.get(0, 0, 0) should be(2)
  }

  it should "subtract correctly" in {
    val a = Nd4j.create(Array[Double](1, 2, 3, 4, 5, 6, 7, 8), Array(2, 2, 2))
    val b = a - 100
    a.get(0, 0, 0) should be(1)
    b.get(0, 0, 0) should be(-99)
    a -= 1
    a.get(0, 0, 0) should be(0)

    val c = Nd4j.create(Array[Double](1, 2))
    val d = c - c
    d.get(0) should be(0)
    d.get(1) should be(0)
  }

  it should "divide correctly" in {
    val a = Nd4j.create(Array[Double](1, 2, 3, 4, 5, 6, 7, 8), Array(2, 2, 2))
    val b = a / a
    a.get(1, 1, 1) should be(8)
    b.get(1, 1, 1) should be(1)
    a /= a
    a.get(1, 1, 1) should be(1)
  }

  it should "element-by-element multiply correctly" in {
    val a = Nd4j.create(Array[Double](1, 2, 3, 4), Array(4, 1))
    val b = a * a
    a.get(3) should be(4) // [1.0, 2.0, 3.0, 4.0
    b.get(3) should be(16) // [1.0 ,4.0 ,9.0 ,16.0]
    a *= 5 // [5.0 ,10.0 ,15.0 ,20.0]
    a.get(0) should be(5)
  }

  it should "use the update method to mutate values" in {
    val nd3 = Nd4j.create(Array[Double](1, 2, 3, 4, 5, 6, 7, 8), Array(2, 2, 2))
    nd3(0) = 11
    nd3.get(0) should be(11)

    val idx = Array(1, 1, 1)
    nd3(idx) = 100
    nd3.get(idx) should be(100)
  }

  it should "use === for equality comparisons" in {
    val a = Nd4j.create(Array[Double](1, 2))

    val b = Nd4j.create(Array[Double](1, 2))
    val c = a === b
    c.get(0) should be(1)
    c.get(1) should be(1)

    val d = Nd4j.create(Array[Double](10, 20))
    val e = a === d
    e.get(0) should be(0)
    e.get(1) should be(0)

    val f = a === 1 // === from our DSL
    f.get(0) should be(1)
    f.get(1) should be(0)
  }

  it should "use - prefix for negation" in {
    val a = Nd4j.create(Array[Double](1, 3))
    val b = -a
    b.get(0) should be(-1)
    b.get(1) should be(-3)
  }
}