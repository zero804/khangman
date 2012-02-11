/******************************************************************************
 * This file is part of the KHangMan project
 * Copyright (C) 2012 Laszlo Papp <lpapp@kde.org>
 *
 * This library is free software; you can redistribute it and/or
 * modify it under the terms of the GNU Lesser General Public
 * License as published by the Free Software Foundation; either
 * version 2.1 of the License, or (at your option) any later version.
 *
 * This library is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 * Lesser General Public License for more details.
 *
 * You should have received a copy of the GNU Lesser General Public
 * License along with this library; if not, write to the Free Software
 * Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301  USA
 */

import QtQuick 1.1
import com.nokia.meego 1.0
import com.nokia.extras 1.0
import QtMultimediaKit 1.1

import "array.js" as MyArray

Page {

    orientationLock: PageOrientation.LockLandscape;

    property variant anagram: khangmanEngineHelper.createNextAnagram();
    property int anagramStatus: anagramStatusEnumeration.init;
    property int currentOriginalWordIndex: 0;
    property color originalWordLetterRectangleColor: Qt.rgba(0, 0, 0, 0);
    property int countDownTimerValue: khangmanEngineHelper.resolveTime;

    QtObject {  // status enum hackery :)
      id: anagramStatusEnumeration;
      property int init: 1;
      property int active: 2;
      property int resolved: 3;
    }

    onStatusChanged: {
        if (status == PageStatus.Active) {
            secondTimer.repeat = true;
            secondTimer.restart();
        }
    }

    function pushPage(file) {
        var component = Qt.createComponent(file)
        if (component.status == Component.Ready)
            pageStack.push(component);
        else
            console.log("Error loading component:", component.errorString());
    }

    function resolveWord() {
        originalWordLetterRepeater.model = khangmanEngineHelper.anagramOriginalWord();
        currentOriginalWordIndex = originalWordLetterRepeater.model.length;
        anagramStatus = anagramStatusEnumeration.resolved;
        anagramHintInfoBanner.hide();
    }

    function nextAnagram() {
        anagramHintInfoBanner.hide();
        anagramStatus = anagramStatusEnumeration.init;
        anagram = khangmanEngineHelper.createNextAnagram();
        anagramLetterRepeater.model = anagram;
        originalWordLetterRepeater.model = anagram;
        currentOriginalWordIndex = 0;
        countDownTimerValue = khangmanEngineHelper.resolveTime;
        MyArray.sourceDestinationLetterIndexHash = [];
    }

    // Create an info banner with icon
    InfoBanner {
        id: khangmanHintInfoBanner;
        text: qsTr("This is an info banner with icon");
        iconSource: "dialog-information.png";
    }

    SoundEffect {
        id: ewDialogAppearSoundEffect;
        source: "EW_Dialogue_Appear.wav";
    }

    SoundEffect {
        id: nextWordSoundEffect;
        source: "new_game.wav";
    }

    SoundEffect {
        id: splashSoundEffect;
        source: "splash.wav";
    }

    // These tools are available for the main page by assigning the
    // id to the main page's tools property
    ToolBarLayout {
        id: mainPageTools;
        visible: false;

        ToolIcon {
            iconSource: "help-hint.png";

            onClicked: {
                khangmanHintInfoBanner.text = khangmanEngine.hint();
                khangmanHintInfoBanner.timerShowTime = khangmanEngineHelper.hintHideTime * 1000;

                // Display the info banner
                khangmanHintInfoBanner.show();
            }
        }

        ToolIcon {
            iconSource: "games-solve.png";

            onClicked: {
                resolveWord();

                secondTimer.repeat = false;
                secondTimer.stop();
            }
        }

        ToolIcon {
            iconSource: "go-next.png";

            onClicked: {
                if (khangmanEngineHelper.useSounds) {
                    nextWordSoundEffect.play();
                }

                nextWord();
                secondTimer.repeat = true;
                secondTimer.restart();
            }
        }

        ToolIcon {
            iconSource: "settings.png";

            onClicked: {
                khangmanHintInfoBanner.hide();
                pageStack.push(mainSettingsPage);

                secondTimer.repeat = false;
                secondTimer.stop();
            }
        }
    }

    tools: mainPageTools;

    // Create a selection dialog with the vocabulary titles to choose from.
    MySelectionDialog {
        id: categorySelectionDialog;
        titleText: "Choose the word category"
        selectedIndex: 1;

        model: khangmanGame.vocabularyList();

        onSelectedIndexChanged: {

            if (khangmanEngineHelper.useSounds) {
                nextWordSoundEffect.play();
            }

            khangmanGame.useVocabulary(selectedIndex);
            nextWord();
        }
    }

    Timer {
        id: secondTimer;
        interval: 1000;
        repeat: true;
        running: false;
        triggeredOnStart: false;

        onTriggered: {
             if (khangmanEngineHelper.resolveTime != 0 && --countDownTimerValue == 0) {
                 stop();
                 if (khangmanEngineHelper.useSounds) {
                    ewDialogAppearSoundEffect.play();
                 }
             }
        }
    }

    Timer {
        id: khangmanResultTimer;
        interval: 1000;
        repeat: false;
        running: false;
        triggeredOnStart: false;

        onTriggered: {
            originalWordLetterRectangleColor = Qt.rgba(0, 0, 0, 0);
            nextAnagram();

            secondTimer.repeat = true;
            secondTimer.start();
        }
    }

    Row {
        spacing: 5;

        anchors {
            right: parent.right;
            top: parent.top;
            topMargin: 5;
            rightMargin: 5;
        }

        LetterElement {
            letterText: Math.floor(countDownTimerValue / 60 / 10);
            visible: khangmanEngineHelper.resolveTime == 0 ? false : true;
        }

        LetterElement {
            letterText: Math.floor(countDownTimerValue / 60 % 10);
            visible: khangmanEngineHelper.resolveTime == 0 ? false : true;
        }

        LetterElement {
            letterText: ":";
            visible: khangmanEngineHelper.resolveTime == 0 ? false : true;
        }

        LetterElement {
            letterText: Math.floor(countDownTimerValue % 60 / 10);
            visible: khangmanEngineHelper.resolveTime == 0 ? false : true;
        }

        LetterElement {
            letterText: Math.floor(countDownTimerValue % 60 % 10);
            visible: khangmanEngineHelper.resolveTime == 0 ? false : true;
        }
    }

    Column {
        anchors {
            horizontalCenter: parent.horizontalCenter;
            verticalCenter: parent.verticalCenter;
        }

        spacing: 20;
        Row {
            id: originalWordRow;
            anchors {
                horizontalCenter: parent.horizontalCenter;
            }

            spacing: 10;
            Repeater {
                id: originalWordLetterRepeater;
                model: anagram;
                LetterElement {
                    id: originalWordLetterId;
                    letterText: modelData;

                    MouseArea {
                        anchors.fill: parent;
                        hoverEnabled: true;

                        onClicked: {
                            if (anagramStatus != anagramStatusEnumeration.resolved)
                            {
                                if (anagramLetterId.letterText != "")
                                {
                                    anagramStatus = anagramStatusEnumeration.active;

                                    originalWordLetterRepeater.model =
                                        khangmanEngineHelper.insertInCurrentOriginalWord(currentOriginalWordIndex, anagramLetterId.letterText);

                                    ++currentOriginalWordIndex;

                                    var tmpAnagramLetterRepeaterModel = anagramLetterRepeater.model;
                                    tmpAnagramLetterRepeaterModel[[index]] = "";
                                    anagramLetterRepeater.model = tmpAnagramLetterRepeaterModel;

                                    MyArray.sourceDestinationLetterIndexHash.push(index);
                                }

                                if (currentOriginalWordIndex == originalWordLetterRepeater.model.length)
                                {
                                    khangmanResultTimer.start();
                                    anagramStatus = anagramStatusEnumeration.resolved;
                                    jhangmanHintInfoBanner.hide();
                                    if (khangmanEngineHelper.compareWords() == true)
                                    {
                                        originalWordLetterRectangleColor = "green";

                                        if (khangmanEngineHelper.useSounds) {
                                            rightSoundEffect.play();
                                        }
                                    }
                                    else
                                    {
                                        originalWordLetterRectangleColor = "red";

                                        if (khangmanEngineHelper.useSounds) {
                                            wrongSoundEffect.play();
                                        }
                                    }
                                }
                            }
                       }
                    }
                }
            }
        }

        Button {
            text: categorySelectionDialog.model[categorySelectionDialog.selectedIndex];

            anchors {
                horizontalCenter: parent.horizontalCenter;
            }

            onClicked: {
                categorySelectionDialog.open();
            }
        }

        Row {
            id: originalWordRow;
            anchors {
                horizontalCenter: parent.horizontalCenter;
            }

            spacing: 10;
            Repeater {
                id: originalWordLetterRepeater;
                model: anagram;
                LetterElement {
                    id: originalWordLetterId;
                    color: originalWordLetterRectangleColor;
                    letterText: anagramStatus == anagramStatusEnumeration.init ? "" : modelData;

                    MouseArea {
                        anchors.fill: parent;
                        hoverEnabled: true;

                        onClicked: {
                            if (index + 1 == currentOriginalWordIndex && currentOriginalWordIndex != 0) {

                                var tmpAnagramLetterRepeaterModel = anagramLetterRepeater.model;
                                tmpAnagramLetterRepeaterModel[MyArray.sourceDestinationLetterIndexHash[index]] = originalWordLetterId.letterText;
                                anagramLetterRepeater.model = tmpAnagramLetterRepeaterModel;

                                MyArray.sourceDestinationLetterIndexHash.pop();

                                originalWordLetterRepeater.model = khangmanEngineHelper.removeInCurrentOriginalWord(index);
                                --currentOriginalWordIndex;
                            }
                        }
                    }
                }
            }
        }
    }
}