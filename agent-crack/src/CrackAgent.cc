/* CrackAgent.cc
 *
 * An agent for reading the crack configuration file.
 *
 * Authors: Jiri Suchomel <jsuchome@suse.cz>
 *
 * $Id$
 */

#include "CrackAgent.h"

/**
 * Constructor
 */
CrackAgent::CrackAgent() : SCRAgent()
{
}

/**
 * Destructor
 */
CrackAgent::~CrackAgent()
{
}

/**
 * Dir
 */
YCPValue CrackAgent::Dir(const YCPPath& path)
{
    y2error("Wrong path '%s' in Read().", path->toString().c_str());
    return YCPVoid();
}

/**
 * Read
 */
YCPValue CrackAgent::Read(const YCPPath &path, const YCPValue& arg)
{
    y2error("Wrong path '%s' in Read().", path->toString().c_str());
    return YCPVoid();
}

/**
 * Write
 */
YCPValue CrackAgent::Write(const YCPPath &path, const YCPValue& value,
    const YCPValue& arg)
{
    y2error("Wrong path '%s' in Write().", path->toString().c_str());
    return YCPVoid();
}

/**
 * Execute
 */
YCPValue CrackAgent::Execute(const YCPPath &path, const YCPValue& value,
	   const YCPValue& arg)
{
    char *pass = (char *) value->toString().c_str();
    const char *dictpath = "/usr/lib/cracklib_dict";
    if (!arg.isNull())
    {
	dictpath = arg->asString()->value().c_str();
    }

    char *out = (char*) FascistCheck (pass, (char *) dictpath);
    if (out) {
	return YCPString (out);
    }
    else {
	return YCPString ("OK");
    }
}

/**
 * otherCommand
 */
YCPValue CrackAgent::otherCommand(const YCPTerm& term)
{
    string sym = term->symbol()->symbol();

    if (sym == "CrackAgent") {
        /* Your initialization */
        return YCPVoid();
    }

    return YCPNull();
}
