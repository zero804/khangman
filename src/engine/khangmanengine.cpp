/***************************************************************************
 *   Copyright 2001-2009 Anne-Marie Mahfouf <annma@kde.org>                *
 *                                                                         *
 *                                                                         *
 *   This program is free software; you can redistribute it and/or modify  *
 *   it under the terms of the GNU General Public License as published by  *
 *   the Free Software Foundation; either version 2 of the License, or     *
 *   (at your option) any later version.                                   *
 *                                                                         *
 *   This program is distributed in the hope that it will be useful,       *
 *   but WITHOUT ANY WARRANTY; without even the implied warranty of        *
 *   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the         *
 *   GNU General Public License for more details.                          *
 *                                                                         *
 *   You should have received a copy of the GNU General Public License     *
 *   along with this program; if not, write to the                         *
 *   Free Software Foundation, Inc.,                                       *
 *   51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.         *
 ***************************************************************************/

#include "khangmanengine.h"

#include "prefs.h"

#include <keduvoclesson.h>
#include <keduvocexpression.h>
#include <keduvocdocument.h>
#include <sharedkvtmlfiles.h>

#include <KLocalizedString>

#include <QApplication>

KHangManEngine::KHangManEngine()
    : m_randomInt(0)
    , m_doc(0)
{
    loadVocabularies();
    nextWord();
}

KHangManEngine::~KHangManEngine()
{
}

bool KHangManEngine::hasSpecialChars(const QString& languageCode)
{
    if (languageCode == QLatin1String("en")
            || languageCode == QLatin1String("en_GB")
            || languageCode == QLatin1String("it")
            || languageCode == QLatin1String("nl")
            || languageCode == QLatin1String("ru")
            || languageCode == QLatin1String("bg")
            || languageCode == QLatin1String("uk")
            || languageCode == QLatin1String("el")
            || languageCode == QLatin1String("ro"))
    {
        return false;
    }
    return true;
}

bool KHangManEngine::hasAccentedLetters(const QString& languageCode)
{
    if (languageCode == QLatin1String("es")
            || languageCode == QLatin1String("ca")
            || languageCode == QLatin1String("pt")
            || languageCode == QLatin1String("pt_BR"))
    {
        return true;
    }
    return false;
}

void KHangManEngine::loadVocabularies()
{
    m_titleLevels.clear();
    QStringList levelFilenames = SharedKvtmlFiles::fileNames(Prefs::selectedLanguage());
    QStringList titles = SharedKvtmlFiles::titles(Prefs::selectedLanguage());

    if (levelFilenames.size() == 0) {
        Prefs::setSelectedLanguage("en");
        Prefs::self()->save();
        levelFilenames = SharedKvtmlFiles::fileNames(Prefs::selectedLanguage());
        titles = SharedKvtmlFiles::titles(Prefs::selectedLanguage());
    }

    if (levelFilenames.isEmpty()) {
        QApplication::instance()->quit();
    }

    Q_ASSERT(levelFilenames.count() == titles.count());
    for(int i = 0; i < levelFilenames.count(); ++i) {
        m_titleLevels.insert(titles.at(i), levelFilenames.at(i));
    }

    if (!levelFilenames.contains(Prefs::levelFile())) {
        Prefs::setLevelFile(m_titleLevels.constBegin().value());
        Prefs::setCurrentLevel(0);
        Prefs::self()->save();
    }

    readFile();
}

void KHangManEngine::readFile()
{
    if (!QFileInfo(Prefs::levelFile()).exists()) {
        qDebug() << i18n("File $KDEDIR/share/apps/kvtml/%1/%2 not found. Please check your installation.", Prefs::selectedLanguage(), Prefs::levelFile());
        QApplication::instance()->quit();
    }

    delete m_doc;
    m_doc = new KEduVocDocument(this);
    ///@todo open returns KEduVocDocument::ErrorCode
    m_doc->open(Prefs::levelFile());

    // Get the words+hints
    m_randomList.clear();

    QList<KEduVocExpression*> entries = m_doc->lesson()->entries(KEduVocLesson::Recursive);
    foreach (KEduVocExpression* entry, entries) {

        QString hint = entry->translation(0)->comment();
        if (hint.isEmpty() && m_doc->identifierCount() > 0) {
            // If there is no comment or it is empty, use the first translation
            // if there is one
            hint = entry->translation(1)->text();
        }

        if (!entry->translation(0)->text().isEmpty()) {
            m_randomList.append(qMakePair(entry->translation(0)->text(), hint));
        }
    }

    // Shuffle the list
    KRandomSequence randomSequence;
    randomSequence.randomize(m_randomList);
}

QString KHangManEngine::stripAccents(const QString &original)
{
    QString noAccents;

    QString decomposed = original.normalized(QString::NormalizationForm_D);
    foreach (const QChar &ch, decomposed) {
        if ( ch.category() != QChar::Mark_NonSpacing ) {
            noAccents.append(ch);
        }
    }

    return noAccents;
}

QString KHangManEngine::hint() const
{
    return m_hint;
}

QString KHangManEngine::word() const
{
    return m_originalWord;
}

QString KHangManEngine::currentWord() const
{
    return m_currentWord;
}

QStringList KHangManEngine::categoryList() const
{
    return m_titleLevels.keys();
}

bool KHangManEngine::containsChar(const QString &sChar)
{
    return m_originalWord.contains(sChar) || stripAccents(m_originalWord).contains(sChar);
}

bool KHangManEngine::isResolved() const
{
    return m_currentWord == m_originalWord;
}

void KHangManEngine::replaceLetters(const QString& charString)
{
    QChar ch = charString.at(0);
    bool oneLetter = Prefs::oneLetter();

    for (int i = 0; i < m_originalWord.size(); ++i) {
        if (m_originalWord.at(i) == ch) {
            m_currentWord[i] = ch;

            if (oneLetter)
                break;
        }
    }
}

int KHangManEngine::currentLevel() const
{
    return Prefs::currentLevel();
}

void KHangManEngine::selectCurrentLevel(int index)
{
    Prefs::setCurrentLevel(index);
}

void KHangManEngine::selectLevelFile(int index)
{
    Prefs::setLevelFile(m_titleLevels.values().at(index));
}

void KHangManEngine::nextWord()
{
    m_originalWord = m_randomList[m_randomInt%m_randomList.count()].first;
    m_originalWord = m_originalWord.toUpper();
    m_hint = m_randomList[m_randomInt%m_randomList.count()].second;

    if (m_originalWord.isEmpty()) {
        ++m_randomInt;
        nextWord();
    }

    m_currentWord.clear();

    int originalWordSize = m_originalWord.size();

    while (m_currentWord.size() < originalWordSize)
        m_currentWord.append("_");

    ++m_randomInt;
}

#include "khangmanengine.moc"