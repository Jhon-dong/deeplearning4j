/*******************************************************************************
 * Copyright (c) 2020 Konduit K.K.
 *
 * This program and the accompanying materials are made available under the
 * terms of the Apache License, Version 2.0 which is available at
 * https://www.apache.org/licenses/LICENSE-2.0.
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS, WITHOUT
 * WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the
 * License for the specific language governing permissions and limitations
 * under the License.
 *
 * SPDX-License-Identifier: Apache-2.0
 ******************************************************************************/
package org.deeplearning4j.rl4j.agent.update;

import lombok.Getter;
import org.deeplearning4j.rl4j.learning.sync.Transition;
import org.deeplearning4j.rl4j.learning.sync.qlearning.TargetQNetworkSource;
import org.deeplearning4j.rl4j.learning.sync.qlearning.discrete.TDTargetAlgorithm.DoubleDQN;
import org.deeplearning4j.rl4j.learning.sync.qlearning.discrete.TDTargetAlgorithm.ITDTargetAlgorithm;
import org.deeplearning4j.rl4j.learning.sync.qlearning.discrete.TDTargetAlgorithm.StandardDQN;
import org.deeplearning4j.rl4j.network.dqn.IDQN;
import org.nd4j.linalg.dataset.api.DataSet;

import java.util.List;

// Temporary class that will be replaced with a more generic class that delegates gradient computation
// and network update to sub components.
public class DQNNeuralNetUpdateRule implements IUpdateRule<Transition<Integer>>, TargetQNetworkSource {

    @Getter
    private final IDQN qNetwork;

    @Getter
    private IDQN targetQNetwork;
    private final int targetUpdateFrequency;

    private final ITDTargetAlgorithm<Integer> tdTargetAlgorithm;

    @Getter
    private int updateCount = 0;

    public DQNNeuralNetUpdateRule(IDQN qNetwork, int targetUpdateFrequency, boolean isDoubleDQN, double gamma, double errorClamp) {
        this.qNetwork = qNetwork;
        this.targetQNetwork = qNetwork.clone();
        this.targetUpdateFrequency = targetUpdateFrequency;
        tdTargetAlgorithm = isDoubleDQN
                ? new DoubleDQN(this, gamma, errorClamp)
                : new StandardDQN(this, gamma, errorClamp);
    }

    @Override
    public void update(List<Transition<Integer>> trainingBatch) {
        DataSet targets = tdTargetAlgorithm.computeTDTargets(trainingBatch);
        qNetwork.fit(targets.getFeatures(), targets.getLabels());
        if(++updateCount % targetUpdateFrequency == 0) {
            targetQNetwork = qNetwork.clone();
        }
    }
}
